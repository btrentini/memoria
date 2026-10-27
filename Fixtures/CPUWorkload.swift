import Foundation

private final class WorkloadResult:@unchecked Sendable {
    private let lock=NSLock()
    private var sum=0.0
    func add(_ value:Double) {lock.lock();sum += value;lock.unlock()}
    func value() -> Double {lock.lock();defer{lock.unlock()};return sum}
}
func runCPUWorkload(workers:Int,seconds:Double) -> Double {
    let queue=OperationQueue(),result=WorkloadResult()
    let count=min(8,max(1,workers)),deadline=ProcessInfo.processInfo.systemUptime+min(120,max(1,seconds))
    queue.maxConcurrentOperationCount=count
    for _ in 0..<count {
        queue.addOperation {
            var accumulator=0.0
            while ProcessInfo.processInfo.systemUptime < deadline {for i in 1...10000 {accumulator += sqrt(Double(i))}}
            result.add(accumulator)
        }
    }
    queue.waitUntilAllOperationsAreFinished()
    return result.value()
}
