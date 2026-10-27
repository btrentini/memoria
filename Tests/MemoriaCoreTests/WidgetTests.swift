import Foundation
import Testing
import MemoriaWidgetSupport

@Suite("Widget snapshot and menu-bar boundaries") struct WidgetTests {
    private let date=Date(timeIntervalSince1970:1_700_000_000)
    private func sample(cpu:Double?=25,used:UInt64?=1024,total:UInt64?=4096,history:[SummaryPoint]=[],schema:Int=1) -> WidgetSummary {
        WidgetSummary(capturedAt:date,cpuPercent:cpu,accountedMemory:used,totalMemory:total,pressure:.normal,history:history,schema:schema)
    }
    @Test func aggregateRoundTripAndPrivacy() throws {
        let value=sample(history:[SummaryPoint(date:date.addingTimeInterval(-5),cpu:0),SummaryPoint(date:date,cpu:nil)])
        let data=try value.encoded()
        #expect(try WidgetSummary.decode(data) == value)
        #expect(value.memoryPercent == 25)
        let keys=Set(try #require(JSONSerialization.jsonObject(with:data) as? [String:Any]).keys)
        #expect(keys == Set(["schema","capturedAt","state","cpuPercent","accountedMemory","totalMemory","pressure","history"]))
        #expect(data.count<WidgetSummary.maxBytes)
    }
    @Test func missingIsDistinctFromZero() throws {
        let absent=try WidgetSummary.decode(sample(cpu:nil,used:nil,total:nil).encoded())
        #expect(absent.cpuPercent == nil);#expect(absent.memoryPercent == nil)
        let zero=try WidgetSummary.decode(sample(cpu:0,used:0).encoded())
        #expect(zero.cpuPercent == 0);#expect(zero.memoryPercent == 0)
    }
    @Test func rejectVersionRangesOversizeAndMalformedSnapshots() {
        #expect(!sample(schema:2).isValid)
        #expect(!sample(cpu:101).isValid);#expect(!sample(cpu:.nan).isValid)
        #expect(!sample(used:5000,total:4096).isValid);#expect(!sample(total:0).isValid)
        #expect(throws:(any Error).self) {try WidgetSummary.decode(Data(repeating:120,count:WidgetSummary.maxBytes+1))}
        #expect(throws:(any Error).self) {try WidgetSummary.decode(Data("{bad".utf8))}
        #expect(throws:(any Error).self) {try sample(cpu:-1).encoded()}
    }
    @Test func historyBoundAndClockChanges() {
        #expect(!sample(history:(0..<31).map {SummaryPoint(date:date.addingTimeInterval(Double($0)-31),cpu:1)}).isValid)
        #expect(!sample(history:[SummaryPoint(date:date.addingTimeInterval(-121),cpu:1)]).isValid)
        #expect(!sample(history:[SummaryPoint(date:date.addingTimeInterval(1),cpu:1)]).isValid)
        #expect(!sample(history:[SummaryPoint(date:date,cpu:1),SummaryPoint(date:date,cpu:2)]).isValid)
        #expect(sample().freshness(at:date.addingTimeInterval(299)) == .snapshot)
        #expect(sample().freshness(at:date.addingTimeInterval(300)) == .stale)
        #expect(sample().freshness(at:date.addingTimeInterval(-6)) == .stale)
        let paused=WidgetSummary(capturedAt:date,state:.paused,cpuPercent:nil,accountedMemory:nil,totalMemory:nil,pressure:.unknown)
        #expect(paused.isValid);#expect(paused.freshness(at:date.addingTimeInterval(500)) == .paused)
    }
    @Test func fixedFileAtomicReplacementDeletionAndLimits() async throws {
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {try? FileManager.default.removeItem(at:folder)}
        let store=SummaryStore(directory:folder)
        #expect(try await store.read() == nil)
        try await store.write(sample());#expect(try await store.read() == sample())
        try await store.write(sample(cpu:0));#expect(try await store.read()?.cpuPercent == 0)
        let file=folder.appendingPathComponent(SummaryStore.filename)
        let permissions=try FileManager.default.attributesOfItem(atPath:file.path)[.posixPermissions] as? NSNumber
        #expect((permissions?.intValue ?? 0)&0o777 == 0o600)
        try Data(repeating:120,count:WidgetSummary.maxBytes+1).write(to:file)
        do {_=try await store.read();Issue.record("Oversized cache accepted")} catch {#expect(error is SummaryStoreError)}
        try await store.remove();#expect(try await store.read() == nil)
        #expect(try FileManager.default.contentsOfDirectory(atPath:folder.path).isEmpty)
    }
    @Test func symlinkCacheIsNotRead() async throws {
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        defer {try? FileManager.default.removeItem(at:folder)}
        let target=folder.appendingPathComponent("target.json")
        try sample().encoded().write(to:target)
        try FileManager.default.createSymbolicLink(at:folder.appendingPathComponent(SummaryStore.filename),withDestinationURL:target)
        do {_=try await SummaryStore(directory:folder).read();Issue.record("Symlink cache accepted")} catch {#expect(error is SummaryStoreError)}
    }
    @Test func publicationAndReloadCadence() {
        var policy=SummaryPublicationPolicy()
        let initial=policy.shouldAttempt(now:0,state:"captured")
        let early=policy.shouldAttempt(now:29,state:"captured")
        let due=policy.shouldAttempt(now:30,state:"captured")
        let paused=policy.shouldAttempt(now:31,state:"paused")
        let firstReload=policy.shouldReload(now:0)
        let earlyReload=policy.shouldReload(now:899)
        let dueReload=policy.shouldReload(now:900)
        let manualReload=policy.shouldReload(now:901,force:true)
        let clockReset=policy.shouldAttempt(now:2,state:"captured")
        let invalidAttempt=policy.shouldAttempt(now:.nan,state:"captured")
        let invalidReload=policy.shouldReload(now:-1)
        #expect(initial && !early && due && paused)
        #expect(firstReload && !earlyReload && dueReload && manualReload)
        #expect(clockReset && !invalidAttempt && !invalidReload)
    }
    @Test func exactAppGroupAndNavigationOnlyRoutes() {
        #expect(WidgetGroup.validIdentifier("AB12CD34EF.fyi.trentini.memoria.shared"))
        for group in ["","group.fyi.trentini.memoria.shared","$(TeamIdentifierPrefix)fyi.trentini.memoria.shared","AB12CD34EF.other","ab12cd34ef.fyi.trentini.memoria.shared"] {#expect(!WidgetGroup.validIdentifier(group))}
        for route in [WidgetRoute.overview,.cpu,.memory,.quick] {#expect(WidgetRoute(url:route.url) == route)}
        for text in ["memoria://kill","memoria://cpu?pid=1","memoria://memory#kill","memoria://user@cpu","memoria://cpu:80","memoria://cpu/path","https://cpu"] {
            #expect(WidgetRoute(url:URL(string:text)!) == nil)
        }
    }
    @Test func menuBarZeroMissingAndPause() {
        #expect(MenuBarReading.cpu.text(cpu:0,memory:nil,paused:false) == "CPU 0%")
        #expect(MenuBarReading.cpu.text(cpu:nil,memory:nil,paused:false) == "CPU —")
        #expect(MenuBarReading.both.text(cpu:12,memory:8_589_934_592,paused:false).contains("8.0G"))
        #expect(MenuBarReading.memory.text(cpu:12,memory:nil,paused:true) == "Paused")
        #expect(MenuBarReading.icon.text(cpu:nil,memory:nil,paused:false).isEmpty)
    }
}
