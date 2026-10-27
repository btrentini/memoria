import Foundation
import Darwin
import Testing
import MemoriaCore
import MemoriaCollectors
import MemoriaServices

private actor TreeBackend:ProcessActionBackend {
    var processes:[Int32:ProcessSnapshot]
    var signals:[Int32]=[]
    let denied:Int32
    init(_ processes:[ProcessSnapshot],denied:Int32) {
        self.processes=Dictionary(uniqueKeysWithValues:processes.map{($0.identity.pid,$0)})
        self.denied=denied
    }
    func inspect(_ pid:Int32) throws -> ProcessSnapshot {
        guard let process=processes[pid] else {throw InspectionError.system(ESRCH)}
        return process
    }
    func signal(_ pid:Int32,number:Int32) -> Int32 {
        signals.append(pid)
        if pid==denied {return EPERM}
        processes.removeValue(forKey:pid);return 0
    }
}
@Suite("Reviewed tree scope") struct TreeActionTests {
    @Test func partialFailurePreservesReviewedOrder() async throws {
        let parent=specimen(pid:100),child=specimen(pid:101,parent:100),grandchild=specimen(pid:102,parent:101)
        let backend=TreeBackend([parent,child,grandchild],denied:101)
        let targets=[grandchild,child,parent].compactMap(TerminationTarget.init)
        let result=await ProcessActionCoordinator(backend:backend).perform(TerminationRequest(targets:targets,action:.terminate,confirmed:true),observationSeconds:0)
        #expect(await backend.signals == [102,101,100])
        #expect(result.map(\.status) == [.exitObserved,.denied,.exitObserved])
        #expect(result[1].errorNumber == EPERM)
    }
    @Test func cancellationBeforeActionSendsNothing() async throws {
        let backend=TreeBackend([specimen()],denied:0)
        let target=try #require(TerminationTarget(process:specimen()))
        let task=Task {
            do {try await Task.sleep(for:.milliseconds(100))} catch {}
            return await ProcessActionCoordinator(backend:backend).perform(TerminationRequest(targets:[target],action:.terminate,confirmed:true))
        }
        task.cancel()
        let results=await task.value
        #expect(results.first?.status == .cancelled)
        #expect(await backend.signals.isEmpty)
    }
}
