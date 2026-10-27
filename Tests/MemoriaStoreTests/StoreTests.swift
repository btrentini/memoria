import Foundation
import Testing
@testable import MemoriaStoreMetrics
import MemoriaWidgetSupport

@Suite("App Store monitoring boundaries") struct StoreTests {
    func sample(_ time:Double,_ ticks:[StoreCPUTicks]) -> StoreSnapshot {
        StoreSnapshot(date:Date(timeIntervalSince1970:1000+time),monotonic:time,ticks:ticks)
    }
    @Test func cpuUsesWholeMachineAverageAndRequiresBaseline() {
        let old=sample(1,[.init(user:0,system:0,idle:0),.init(user:0,system:0,idle:0)])
        let new=sample(3,[.init(user:80,system:20,idle:0),.init(user:0,system:0,idle:100)])
        #expect(StoreDeltas.apply(new,previous:nil).cpu==nil)
        #expect(StoreDeltas.apply(new,previous:old).cpu==50)
    }
    @Test func sleepCounterResetAndCoreChangeAreGaps() {
        let old=sample(1,[.init(user:100,system:10,idle:50)])
        #expect(StoreDeltas.apply(sample(30,[.init(user:200,system:20,idle:60)]),previous:old).cpu==nil)
        #expect(StoreDeltas.apply(sample(3,[.init(user:0,system:0,idle:0)]),previous:old).cpu==nil)
        #expect(StoreDeltas.apply(sample(3,[]),previous:old).cpu==nil)
        #expect(StoreDeltas.apply(sample(1,[.init(user:200,system:20,idle:60)]),previous:old).cpu==nil)
    }
    @Test func interfaceCountersRemainSeparateAndRebaseline() {
        let a=StoreInterface(name:"en0",index:1,kind:"Physical",received:100,sent:200)
        let b=StoreInterface(name:"utun0",index:2,kind:"Tunnel",received:500,sent:600)
        var before=sample(1,[]);before.interfaces=[a,b]
        var next=sample(3,[])
        next.interfaces=[StoreInterface(name:"en0",index:1,kind:"Physical",received:300,sent:500),StoreInterface(name:"utun0",index:2,kind:"Tunnel",received:1,sent:2)]
        let result=StoreDeltas.apply(next,previous:before)
        #expect(result.interfaces[0].receiveRate==100)
        #expect(result.interfaces[0].sendRate==150)
        #expect(result.interfaces[1].receiveRate==nil)
    }
    @Test func memoryAccountingAndInvalidOccupancy() {
        let value=StoreMemory(total:100,free:10,active:30,inactive:20,wired:10,compressed:15)
        #expect(value.accounted==55)
        #expect(abs((value.percent ?? 0)-55)<0.000001)
        #expect(StoreMemory(total:1,free:0,active:2,inactive:0,wired:0,compressed:0).percent==nil)
    }
    @Test func storeAndDirectRoutesAndCachesStaySeparate() {
        #expect(WidgetGroup.validIdentifier("ABCDE12345.fyi.trentini.memoria.store.shared"))
        #expect(!WidgetGroup.validIdentifier("ABCDE12345.fyi.trentini.anything.shared"))
        #expect(WidgetRoute(url:URL(string:"memoria-store://memory")!)==nil)
        #expect(WidgetRoute(url:URL(string:"memoria-store://memory")!,expectedScheme:"memoria-store") == .memory)
        #expect(WidgetRoute(url:URL(string:"memoria-store://memory?terminate=1")!,expectedScheme:"memoria-store")==nil)
    }
}
