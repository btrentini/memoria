import Foundation
import Testing
import MemoriaCollectors

@Suite("Native executor admission") struct ExecutorTests {
    @Test func boundsAndSkipsCancelledQueueWork() async throws {
        let executor=NativeExecutor(maxPending:2),gate=DispatchSemaphore(value:0)
        let (stream,started)=AsyncStream<Void>.makeStream()
        let first=Task {try await executor.run {started.yield(());_ = gate.wait(timeout:.now()+5);return 1}}
        for await _ in stream {break}
        let second=Task {try await executor.run {2}}
        for _ in 0..<1000 {
            if executor.pendingCount == 2 {break}
            try await Task.sleep(for:.milliseconds(1))
        }
        #expect(executor.pendingCount == 2)
        do {_ = try await executor.run {3};Issue.record("A third operation exceeded the admission limit")}
        catch {#expect(error is InspectionError)}
        second.cancel();gate.signal()
        #expect(try await first.value == 1)
        do {_ = try await second.value;Issue.record("Cancelled queued work ran")}
        catch {#expect(error is CancellationError)}
        #expect(executor.pendingCount == 0)
        started.finish()
    }
}
