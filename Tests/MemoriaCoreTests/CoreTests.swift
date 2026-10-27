import Foundation
import Testing
@testable import MemoriaCore
@testable import MemoriaServices
import MemoriaCollectors

func specimen(pid:Int32=42,start:UInt64=100,path:String="/usr/bin/fixture",parent:Int32=1,cpu:Double?=10) -> ProcessSnapshot {
    ProcessSnapshot(identity:ProcessIdentity(pid:pid,startSeconds:start,startMicroseconds:4,bootSession:"boot-A"),executable:ExecutableIdentity(path:path,device:1,inode:UInt64(max(1,pid))),parentPID:parent,uid:501,name:"fixture \(pid)",state:"Running",cpuPercent:cpu,footprintBytes:1024)
}

@Suite("Accounting and availability") struct AccountingTests {
    @Test func cpuDeltas() {
        let previous=CPUTicks(user:100,system:50,idle:850)
        let usage=CPUTicks(user:130,system:70,idle:900).delta(from:previous)
        #expect(usage == CPUUsage(user:30,system:20,idle:50))
        #expect(DeltaMath.processCPU(nanoseconds:3_000_000_000,previous:1_000_000_000,interval:1) == 200)
        #expect(DeltaMath.machineCPU(oneCore:200,coreCount:10) == 20)
    }
    @Test func resetsAndZeroIntervals() {
        #expect(CPUTicks(user:1,system:1,idle:1).delta(from:CPUTicks(user:2,system:1,idle:1)) == nil)
        #expect(CPUTicks(user:1,system:1,idle:1).delta(from:CPUTicks(user:1,system:1,idle:1)) == nil)
        #expect(DeltaMath.rate(current:2,previous:3,interval:1) == nil)
        #expect(DeltaMath.rate(current:2,previous:1,interval:0) == nil)
        #expect(DeltaMath.rate(current:2,previous:1,interval:.infinity) == nil)
        #expect(DeltaMath.machineCPU(oneCore:20,coreCount:0) == nil)
    }
    @Test func unavailableIsNotZero() {
        let denied=MetricSample(id:"gpu",value:.number(0),unit:.watts,monotonicTime:1,api:"test",availability:.denied)
        let zero=MetricSample(id:"gpu",value:.number(0),unit:.watts,monotonicTime:1,api:"test")
        #expect(denied.value == nil)
        #expect(zero.value?.double == 0)
        #expect(Set([Availability.failed,.denied,.stale,.unsupported,.unavailable]).count == 5)
    }
    @Test func alertHysteresis() {
        var policy=AlertPolicy(high:90,reset:85,requiredSamples:2)
        let trigger1=policy.ingest(91);#expect(!trigger1);let trigger2=policy.ingest(92);#expect(trigger2);let trigger3=policy.ingest(99);#expect(!trigger3)
        let trigger4=policy.ingest(87);#expect(!trigger4);#expect(policy.active)
        let trigger5=policy.ingest(85);#expect(!trigger5);#expect(!policy.active)
        let trigger6=policy.ingest(94);#expect(!trigger6);let trigger7=policy.ingest(nil);#expect(!trigger7);let trigger8=policy.ingest(94);#expect(!trigger8);let trigger9=policy.ingest(95);#expect(trigger9)
    }
}
@Suite("History and privacy") struct HistoryTests {
    @Test func boundsThroughEightSimulatedHours() {
        var history=BoundedHistory()
        for i in 0..<28_800 {history.append(HistoryPoint(date:Date(timeIntervalSince1970:Double(i)),monotonic:Double(i),value:Double(i%100)))}
        #expect(history.count == 3601)
        #expect(history.points.first?.monotonic == 25_199)
        #expect(history.points.last?.monotonic == 28_799)
    }
    @Test func timeBucketsKeepGapsAndClockChanges() {
        var history=BoundedHistory(capacity:30,retention:30)
        for i in 0..<20 {history.append(HistoryPoint(date:Date(timeIntervalSince1970:Double(20-i)),monotonic:Double(i),value:i == 10 ? nil:Double(i)))}
        let points=history.downsample(window:20,endingAt:20,buckets:5)
        #expect(points.count <= 5);#expect(points.contains {$0.value == nil})
        history.append(HistoryPoint(date:.now,monotonic:1,value:100))
        #expect(history.count == 20)
    }
    @Test func exportRoundTripAndRecovery() throws {
        let points=[HistoryPoint(date:Date(timeIntervalSince1970:1),monotonic:2,value:nil),HistoryPoint(date:.now,monotonic:3,value:42)]
        #expect(try JSONDecoder().decode([HistoryPoint].self,from:JSONEncoder().encode(points)) == points)
        let csv=HistoryExport.csv(["cpu":points]);#expect(csv.contains("metric,time,monotonic_seconds,value"));#expect(csv.contains(",2.0,\n"))
        let metric=MetricSample(id:"cpu",value:.number(1),unit:.percent,monotonicTime:1,api:"test")
        let data=try JSONEncoder().encode([metric])+Data("\n{broken\n".utf8)
        let recovered=RecordingStore.recover(data)
        #expect(recovered.samples.count == 1);#expect(recovered.corruptLines == 1)
    }
    @Test func recordingQuotaAndDeletion() async throws {
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {try? FileManager.default.removeItem(at:folder)}
        let store=RecordingStore(directory:folder,quota:1500)
        let metric=MetricSample(id:"cpu",value:.number(10),unit:.percent,monotonicTime:1,api:"test")
        for _ in 0..<10 {try await store.append([metric])}
        let files=try FileManager.default.contentsOfDirectory(at:folder,includingPropertiesForKeys:[.fileSizeKey])
        let size=try files.reduce(0) {$0+(try $1.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0)}
        #expect(size <= 1500)
        try await store.deleteAll();#expect(try FileManager.default.contentsOfDirectory(atPath:folder.path).isEmpty)
    }
}
@Suite("Port queries and fallback parsing") struct PortTests {
    @Test(arguments:["8080",":8080","localhost:8080","127.0.0.1:8080","[::1]:8080","http://localhost:8080/path","tcp://[::1]:8080","8080/tcp"])
    func validQueries(_ input:String) throws {#expect(try PortQuery(input).port == 8080)}
    @Test(arguments:["","0","65536","-1","1;kill","[::1]","::1:8080","https://user:password@localhost:8080","file:///tmp/a","8080/invalid"])
    func invalidQueries(_ input:String) {#expect(throws:(any Error).self) {try PortQuery(input)}}
    @Test func defaultsAndUDP() throws {#expect(try PortQuery("https://localhost").port == 443);#expect(try PortQuery("http://localhost").port == 80);#expect(try PortQuery("udp://localhost:53").transport == .udp)}
    @Test func establishedIsNotListener() throws {
        let p=specimen()
        let endpoint=EndpointRecord(process:p.identity,executable:p.executable,processName:p.name,descriptor:3,family:"IPv4",transport:.tcp,localAddress:"127.0.0.1",localPort:8080,remoteAddress:"127.0.0.1",remotePort:5555,state:"ESTABLISHED")
        let query=try PortQuery("8080")
        #expect(query.matches(endpoint));#expect(!query.matches(endpoint,listenersOnly:true))
    }
    @Test func machineReadableLsof() {
        let raw="p42\0cfixture\0\nf3\0tIPv6\0PTCP\0n[::1]:8080\0TST=LISTEN\0\nf4\0tIPv4\0PUDP\0n*:5353\0\n"
        let parsed=LsofParser.parse(Data(raw.utf8))
        #expect(parsed.count == 2);#expect(parsed.first?.pid == 42);#expect(parsed.first?.state == "LISTEN");#expect(parsed.last?.transport == .udp)
        #expect(LsofParser.parse(Data("garbage\0pbad\0f3\0n8080".utf8)).isEmpty)
    }
}
@Suite("Identity, grouping and events") struct IdentityTests {
    @Test func identitiesAndExec() {
        let original=specimen(),replacement=specimen(start:101),executed=specimen(path:"/bin/other")
        #expect(original.identity != replacement.identity)
        #expect(original.identity == executed.identity)
        #expect(original.executable != executed.executable)
        var events=EventReconciler();events.reconcile([original]);events.ingest(.exec(executed))
        #expect(events.processes.count == 1);#expect(events.processes[original.identity]?.executable == executed.executable)
        events.ingest(.exit(replacement.identity));#expect(events.processes.count == 1)
        events.ingest(.gap);#expect(events.requiresPolling)
        events.ingest(.exit(original.identity));#expect(events.processes.isEmpty)
    }
    @Test func childrenFirstAndCycleBound() {
        let parent=specimen(pid:10),child=specimen(pid:11,parent:10),grandchild=specimen(pid:12,parent:11)
        #expect(ProcessTree.descendants(of:parent.identity,in:[grandchild,parent,child]).map(\.identity.pid) == [12,11])
        let cyclic=specimen(pid:10,parent:12)
        #expect(ProcessTree.descendants(of:cyclic.identity,in:[cyclic,child,grandchild]).count == 2)
    }
    @Test func groupingDistinguishesAncestry() {
        let root=specimen(pid:10,path:"/Applications/Example.app/Contents/MacOS/Main"),helper=specimen(pid:11,path:"/usr/bin/helper",parent:10),shared=specimen(pid:12,path:"/usr/libexec/shared")
        let groups=ApplicationGrouping.group([root,helper,shared])
        #expect(groups.count == 1);#expect(groups[0].members.count == 2)
        #expect(groups[0].members.contains {$0.membership == .inferred})
        #expect(groups[0].footprintSum == 2048)
    }
    @Test func filterFiveThousandRowsBenchmark() {
        let rows=(2..<5002).map {specimen(pid:Int32($0),cpu:Double($0%100))}
        var filter=ProcessFilter();filter.query="fixture";filter.sort = .cpu
        var timings:[Double]=[]
        for _ in 0..<25 {let start=ProcessInfo.processInfo.systemUptime;let sorted=filter.apply(rows);timings.append(ProcessInfo.processInfo.systemUptime-start);#expect(sorted.count == 5000);#expect(sorted.first?.cpuPercent == 99)}
        let p95=timings.sorted()[23];print("BENCHMARK search5000 p95_seconds=\(p95)")
        #expect(p95 < 0.1)
    }
}
@Suite("Worker boundary") struct WorkerTests {
    func line(_ message:WorkerMessage) throws -> Data {try JSONEncoder().encode(message)+Data([10])}
    @Test func handshakeAndFragments() throws {
        var decoder=WorkerDecoder()
        let hello=try line(WorkerMessage(type:"hello",sequence:0,monotonic:1,capabilities:["gpu.power"]))
        #expect(try decoder.feed(hello.prefix(5)).isEmpty)
        #expect(try decoder.feed(hello.dropFirst(5)).count == 1)
        let sample=MetricSample(id:"gpu.power",value:.number(0),unit:.watts,monotonicTime:2,interval:1,api:"test",tier:.experimental)
        #expect(try decoder.feed(line(WorkerMessage(type:"sample",sequence:1,monotonic:2,samples:[sample]))).count == 1)
    }
    @Test func invalidVersionAndSize() throws {
        var decoder=WorkerDecoder()
        #expect(throws:WorkerProtocolError.invalidVersion) {try decoder.feed(line(WorkerMessage(version:2,type:"hello",sequence:0,monotonic:0)))}
        #expect(throws:WorkerProtocolError.oversized) {try decoder.feed(Data(repeating:65,count:65537))}
    }
    @Test func unknownCounterDoesNotBecomeMeasuredZero() throws {
        var decoder=WorkerDecoder();_=try decoder.feed(line(WorkerMessage(type:"hello",sequence:0,monotonic:0,capabilities:[])))
        let sample=MetricSample(id:"ane.power",value:.number(0),unit:.watts,monotonicTime:1,api:"test",tier:.experimental)
        #expect(throws:WorkerProtocolError.invalidMetric) {try decoder.feed(line(WorkerMessage(type:"sample",sequence:1,monotonic:1,samples:[sample])))}
    }
    @Test func replayAndRangeRejected() throws {
        var decoder=WorkerDecoder();_=try decoder.feed(line(WorkerMessage(type:"hello",sequence:0,monotonic:0,capabilities:["gpu"])))
        #expect(throws:WorkerProtocolError.invalidSequence) {try decoder.feed(line(WorkerMessage(type:"sample",sequence:0,monotonic:1)))}
        let impossible=MetricSample(id:"gpu",value:.number(101),unit:.percent,monotonicTime:1,api:"test",tier:.experimental)
        #expect(throws:WorkerProtocolError.invalidMetric) {try decoder.feed(line(WorkerMessage(type:"sample",sequence:1,monotonic:1,samples:[impossible])))}
    }
}
