import Foundation
import Darwin
import Testing
import MemoriaCore
import MemoriaCollectors
import MemoriaServices

private func applicationProcess(pid:Int32=100,start:UInt64=100,parent:Int32=1,
                                path:String="/Applications/Example.app/Contents/MacOS/Example",
                                memory:UInt64?=1024,cpu:Double=5) -> ProcessSnapshot {
    ProcessSnapshot(identity:ProcessIdentity(pid:pid,startSeconds:start,startMicroseconds:0,bootSession:"test-boot"),
        executable:ExecutableIdentity(path:path,device:1,inode:UInt64(max(1,pid))),parentPID:parent,
        uid:501,name:"Example",state:"Running",cpuPercent:cpu,residentBytes:memory,
        footprintBytes:memory,observedAt:Double(start))
}

@Suite("Applications memory and reviewed actions") struct ApplicationTests {
    @Test func memoryWaitsFiveMinutesWhileCPUAndMembershipStayLive() {
        var cache=ApplicationMemorySnapshot()
        let first=applicationProcess(memory:100)
        let initial=cache.refresh(processes:[first],systemAccounted:1000,monotonic:10,date:Date(timeIntervalSince1970:10))
        #expect(initial)
        let changed=applicationProcess(memory:900,cpu:75)
        let early=cache.refresh(processes:[changed],systemAccounted:9000,monotonic:309.999,date:.now)
        #expect(!early)
        let displayed=cache.applying(to:[changed])
        #expect(displayed[0].footprintBytes == 100);#expect(displayed[0].residentBytes == 100)
        #expect(displayed[0].cpuPercent == 75);#expect(cache.systemAccounted == 1000)
        #expect(cache.date == Date(timeIntervalSince1970:10))
        #expect(cache.applying(to:[]).isEmpty)
        let due=cache.refresh(processes:[changed],systemAccounted:9000,monotonic:310,date:.now)
        #expect(due)
        #expect(cache.applying(to:[changed])[0].footprintBytes == 900)
    }
    @Test func reopenClockResetAndSleepCanRebaseline() {
        var cache=ApplicationMemorySnapshot()
        cache.refresh(processes:[applicationProcess(memory:1)],systemAccounted:1,monotonic:100,date:.now)
        let reopened=cache.refresh(processes:[applicationProcess(memory:2)],systemAccounted:2,monotonic:101,date:.now,force:true)
        #expect(reopened)
        #expect(cache.applying(to:[applicationProcess()])[0].footprintBytes == 2)
        let reset=cache.refresh(processes:[],systemAccounted:nil,monotonic:1,date:.now)
        let invalid=cache.refresh(processes:[],systemAccounted:nil,monotonic:.nan,date:.now,force:true)
        #expect(reset);#expect(!invalid)
        cache=ApplicationMemorySnapshot()
        #expect(cache.date == nil);#expect(cache.monotonic == nil)
        #expect(cache.applying(to:[applicationProcess()])[0].footprintBytes == nil)
    }
    @Test func newProcessesReuseAndExecNeverInheritMemory() {
        var cache=ApplicationMemorySnapshot()
        cache.refresh(processes:[applicationProcess(memory:100)],systemAccounted:100,monotonic:1,date:.now)
        let replacements=[applicationProcess(pid:101),applicationProcess(start:200),applicationProcess(path:"/usr/bin/new")]
        #expect(cache.applying(to:replacements).allSatisfy {$0.footprintBytes == nil && $0.residentBytes == nil})
        cache.refresh(processes:replacements,systemAccounted:100,monotonic:301,date:.now)
        #expect(cache.applying(to:[applicationProcess()])[0].footprintBytes == nil)
    }
    @Test func missingAndMeasuredZeroRemainDistinctAndMemoryRankingStable() {
        var cache=ApplicationMemorySnapshot()
        let first=applicationProcess(memory:0),second=applicationProcess(pid:101,memory:nil)
        cache.refresh(processes:[first,second],systemAccounted:0,monotonic:1,date:.now)
        let displayed=cache.applying(to:[applicationProcess(memory:999),applicationProcess(pid:101,memory:999)])
        var filter=ProcessFilter();filter.sort = .memory
        #expect(filter.apply(displayed).map(\.identity.pid) == [100,101])
        #expect(displayed[0].footprintBytes == 0);#expect(displayed[1].footprintBytes == nil)
        #expect(cache.systemAccounted == 0)
    }
    @Test func groupReviewIncludesIndependentHelpersAndExcludesUnassignedServices() throws {
        let parent=applicationProcess(),child=applicationProcess(pid:101,parent:100),grandchild=applicationProcess(pid:102,parent:101)
        let independent=applicationProcess(pid:103),inferred=applicationProcess(pid:104,parent:100,path:"/usr/bin/child")
        let shared=applicationProcess(pid:105,path:"/usr/libexec/shared")
        let group=try #require(ApplicationGrouping.group([parent,child,grandchild,independent,inferred,shared]).first)
        let plan=ApplicationActionPlan(group:group)
        #expect(Set(plan.targets.map(\.identity.pid)) == [100,101,102,103,104])
        #expect(plan.defaultSelection.map(\.pid).sorted() == [100,101,102,103])
        #expect(plan.inferred == [inferred.identity])
        let order=plan.targets.map(\.identity.pid)
        #expect(try #require(order.firstIndex(of:102)) < #require(order.firstIndex(of:101)))
        #expect(try #require(order.firstIndex(of:101)) < #require(order.firstIndex(of:100)))
    }
    @Test func unverifiableGroupMembersAreExplicit() throws {
        let invalid=applicationProcess(pid:101,start:0)
        let group=try #require(ApplicationGrouping.group([applicationProcess(),invalid]).first)
        let plan=ApplicationActionPlan(group:group)
        #expect(plan.unavailable.map(\.identity) == [invalid.identity]);#expect(plan.targets.count == 1)
    }
    @Test func groupActionRevalidatesEveryMemberAndNeverExpandsScope() async throws {
        let main=applicationProcess(),helper=applicationProcess(pid:101,parent:100),denied=applicationProcess(pid:102)
        let plan=ApplicationActionPlan(group:try #require(ApplicationGrouping.group([main,helper,denied]).first))
        let backend=ApplicationBackend([main,applicationProcess(pid:101,start:200,parent:100),denied,applicationProcess(pid:103)],denied:102)
        let result=await ProcessActionCoordinator(backend:backend,excludedPIDs:[]).perform(
            TerminationRequest(targets:plan.targets,action:.terminate,confirmed:true),observationSeconds:0)
        #expect(result.first {$0.target.identity.pid == 101}?.status == .identityChanged)
        #expect(result.first {$0.target.identity.pid == 100}?.status == .exitObserved)
        #expect(result.first {$0.target.identity.pid == 102}?.status == .denied)
        #expect(await backend.signalled == [100,102])
        #expect(await backend.numbers == [SIGTERM,SIGTERM])
    }
}

private actor ApplicationBackend:ProcessActionBackend {
    var processes:[Int32:ProcessSnapshot]
    let denied:Int32
    var signalled:[Int32]=[]
    var numbers:[Int32]=[]
    init(_ processes:[ProcessSnapshot],denied:Int32) {
        self.processes=Dictionary(uniqueKeysWithValues:processes.map {($0.identity.pid,$0)});self.denied=denied
    }
    func inspect(_ pid:Int32) throws -> ProcessSnapshot {
        guard let process=processes[pid] else {throw InspectionError.system(ESRCH)};return process
    }
    func signal(_ pid:Int32,number:Int32) -> Int32 {
        signalled.append(pid);numbers.append(number)
        if pid == denied {return EPERM}
        processes.removeValue(forKey:pid);return 0
    }
}
