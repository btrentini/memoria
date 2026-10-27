import Foundation
import Testing
@testable import MemoriaCore

@Suite("Simplified top-ten summaries") struct TopProcessesTests {
    @Test(arguments:[0,1,9,10,11,5000])
    func limitAfterRanking(_ count:Int) {
        let input=(0..<count).map {specimen(pid:Int32($0+2),cpu:Double($0))}
        let result=TopProcesses.rank(input,context:.cpu,metric:.cpu,currentUID:501)
        #expect(result.processes.count == min(count,10))
        #expect(result.measuredCount == count)
        #expect(result.unavailableCount == 0)
        if count>0 {#expect(result.processes.first?.cpuPercent == Double(count-1))}
        if count>10 {#expect(result.processes.last?.cpuPercent == Double(count-10))}
    }
    @Test func missingAndInvalidAreExcludedButZeroRemainsMeasured() {
        let input=[specimen(pid:2,cpu:nil),specimen(pid:3,cpu:.nan),specimen(pid:4,cpu:-1),specimen(pid:5,cpu:0)]
        let result=TopProcesses.rank(input,context:.cpu,metric:.cpu,currentUID:501)
        #expect(result.processes.map(\.identity.pid) == [5])
        #expect(result.measuredCount == 1)
        #expect(result.unavailableCount == 3)
        #expect(result.processes.first?.cpuPercent == 0)
    }
    @Test func tiesStayStableAndCPUCanExceedOneCore() {
        let result=TopProcesses.rank([specimen(pid:9,cpu:250),specimen(pid:3,cpu:250),specimen(pid:2,cpu:100)],context:.overview,metric:.cpu,currentUID:501)
        #expect(result.processes.map(\.identity.pid) == [3,9,2])
        #expect(result.processes.first?.cpuPercent == 250)
    }
    @Test func applicationSummaryIncludesAssociatedChildrenOnly() {
        let app=specimen(pid:10,path:"/Applications/Example.app/Contents/MacOS/Main",cpu:20)
        let child=specimen(pid:11,parent:10,cpu:50),shared=specimen(pid:12,cpu:99)
        let result=TopProcesses.rank([app,child,shared],context:.applications,metric:.cpu,currentUID:501)
        #expect(result.processes.map(\.identity.pid) == [11,10])
        #expect(result.measuredCount == 2)
    }
    @Test func unsupportedMetricFallsBackWithoutInventedValues() {
        let result=TopProcesses.rank([specimen()],context:.memory,metric:.name,currentUID:501)
        #expect(result.metric == .memory)
        #expect(result.processes.first?.footprintBytes == 1024)
        let unavailable=TopProcesses.rank([specimen()],context:.storage,metric:.io,currentUID:501)
        #expect(unavailable.processes.isEmpty)
        #expect(unavailable.unavailableCount == 1)
    }
}
