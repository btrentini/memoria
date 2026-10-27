import Foundation
import Testing
@testable import MemoriaCore

@Suite("Process ranking across tabs") struct RankingTests {
    private func row(_ pid:Int32,cpu:Double?=10,memory:UInt64?=100,resident:UInt64?=80,threads:UInt32?=2,
                     read:Double?=30,write:Double?=20,uid:UInt32=501,state:String="Running") -> ProcessSnapshot {
        ProcessSnapshot(identity:ProcessIdentity(pid:pid,startSeconds:100,startMicroseconds:0,bootSession:"boot"),
                        executable:nil,parentPID:1,uid:uid,name:"Process \(pid)",state:state,threads:threads,
                        cpuPercent:cpu,residentBytes:resident,footprintBytes:memory,readRate:read,writeRate:write)
    }
    @Test(arguments:ProcessSort.allCases.filter(\.isResource))
    func unavailableLastInBothDirections(_ sort:ProcessSort) {
        let absent=row(2,cpu:nil,memory:nil,resident:nil,threads:nil,read:nil,write:nil)
        let zero=row(3,cpu:0,memory:0,resident:0,threads:0,read:0,write:0)
        let busy=row(4)
        var filter=ProcessFilter();filter.sort=sort
        #expect(filter.apply([absent,zero,busy]).map(\.identity.pid) == [4,3,2])
        filter.descending=false
        #expect(filter.apply([absent,zero,busy]).map(\.identity.pid) == [3,4,2])
        filter.values = .measured
        #expect(filter.apply([absent,zero,busy]).map(\.identity.pid) == [3,4])
        filter.values = .positive
        #expect(filter.apply([absent,zero,busy]).map(\.identity.pid) == [4])
    }
    @Test func stableTiesAndExactLargeMemoryValues() {
        var filter=ProcessFilter()
        for descending in [true,false] {
            filter.descending=descending
            #expect(filter.apply([row(7),row(2),row(4)]).map(\.identity.pid) == [2,4,7])
        }
        filter.sort = .memory;filter.descending=true
        #expect(filter.apply([row(2,memory:UInt64.max-1),row(3,memory:UInt64.max)]).map(\.identity.pid) == [3,2])
    }
    @Test func combinedIODoesNotInventMissingHalf() {
        #expect(ProcessSort.io.value(in:row(2,read:10,write:20)) == 30)
        #expect(ProcessSort.io.value(in:row(2,read:10,write:nil)) == nil)
        #expect(ProcessSort.io.value(in:row(2,read:.infinity,write:0)) == nil)
        #expect(ProcessSort.cpu.value(in:row(2,cpu:.nan)) == nil)
        #expect(ProcessSort.cpu.value(in:row(2,cpu:-1)) == nil)
    }
    @Test func thresholdsScopeStateAndSearchCombine() {
        let rows=[row(2,cpu:50,memory:200),row(3,cpu:5,memory:200),row(4,cpu:50,memory:200,uid:0),
                  row(5,cpu:50,memory:200,state:"Sleeping"),row(6,cpu:50,memory:nil)]
        var settings=ProcessListPreferences(context:.memory)
        settings.scope = .mine;settings.state="Running";settings.minimumCPU=10;settings.minimumMemory=150
        settings.query="Process"
        #expect(settings.apply(to:rows,currentUID:501).map(\.identity.pid) == [2])
        settings.query="missing"
        #expect(settings.apply(to:rows,currentUID:501).isEmpty)
    }
    @Test func tabDefaultsAndPrivateQueryPersistence() throws {
        #expect(ProcessListContext.allCases.count == 13) // Twelve tabs and the quick window.
        var settings=Dictionary(uniqueKeysWithValues:ProcessListContext.allCases.map {($0,ProcessListPreferences(context:$0))})
        settings[.memory]?.query="sensitive path";settings[.memory]?.minimumMemory=100
        settings[.memory]?.sort = .resident
        #expect(settings[.cpu]?.sort == .cpu)
        #expect(settings[.storage]?.sort == .io)
        #expect(settings[.quick]?.query == "")
        let persisted=try JSONDecoder().decode(ProcessListPreferences.self,from:JSONEncoder().encode(settings[.memory]!.persisted))
        #expect(persisted.query.isEmpty);#expect(persisted.sort == .resident);#expect(persisted.minimumMemory == 100)
        #expect(settings[.memory]?.query == "sensitive path")
        for context in [ProcessListContext.gpu,.network,.power] {#expect(context.note.contains("unavailable"))}
    }
    @Test func applicationScopeIncludesInferredChildren() {
        let app=specimen(pid:10,path:"/Applications/Example.app/Contents/MacOS/Main")
        let child=specimen(pid:11,parent:10),shared=specimen(pid:12)
        let settings=ProcessListPreferences(context:.applications)
        #expect(Set(settings.apply(to:[app,child,shared],currentUID:501).map(\.identity.pid)) == [10,11])
    }
    @Test func portSearchKeepsPIDMatchesAndRejectsReusedIdentity() {
        let pidMatch=specimen(pid:8080),listener=specimen(pid:40),replacement=specimen(pid:40,start:101)
        let endpoint=EndpointRecord(process:listener.identity,executable:listener.executable,processName:listener.name,descriptor:3,
                                    family:"IPv4",transport:.tcp,localAddress:"127.0.0.1",localPort:8080,remoteAddress:"",remotePort:0,state:"LISTEN")
        let scan=PortScan(endpoints:[endpoint],deniedOrRaced:1,scanned:3)
        var settings=ProcessListPreferences(context:.ports);settings.query="8080"
        #expect(Set(settings.apply(to:[pidMatch,listener],currentUID:501,scan:scan).map(\.identity.pid)) == [40,8080])
        #expect(settings.apply(to:[pidMatch,replacement],currentUID:501,scan:scan).map(\.identity.pid) == [8080])
    }
    @Test func nonResourceColumnsSortAndTieBreak() {
        let rows=[row(9,uid:0,state:"Stopped"),row(2,uid:501,state:"Running"),row(4,uid:501,state:"Running")]
        var filter=ProcessFilter();filter.descending=false;filter.sort = .owner
        #expect(filter.apply(rows).map(\.identity.pid) == [9,2,4])
        filter.sort = .state
        #expect(filter.apply(rows).map(\.identity.pid) == [2,4,9])
        filter.sort = .pid;filter.descending=true
        #expect(filter.apply(rows).map(\.identity.pid) == [9,4,2])
    }
}
