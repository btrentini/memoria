import Foundation
import AppKit
import Darwin
import MemoriaCore
import MemoriaCollectors

public protocol ProcessActionBackend: Sendable {
    func inspect(_ pid:Int32) async throws -> ProcessSnapshot
    func signal(_ pid:Int32, number:Int32) async -> Int32
}
public struct NativeActionBackend:ProcessActionBackend {
    private let executor=NativeExecutor()
    private let reader=NativeReader()
    public init() {}
    public func inspect(_ pid:Int32) async throws -> ProcessSnapshot { let reader=self.reader; return try await executor.run {try reader.process(pid)} }
    public func signal(_ pid:Int32,number:Int32) async -> Int32 {let reader=self.reader;return (try? await executor.run {reader.signal(pid:pid,number:number)}) ?? EIO}
}
public actor ProcessActionCoordinator {
    private let backend:any ProcessActionBackend
    private var excluded:Set<Int32>
    private let infrastructurePaths:Set<String>
    private var active=false
    public init(backend:any ProcessActionBackend=NativeActionBackend(),excludedPIDs:Set<Int32>=[Int32(ProcessInfo.processInfo.processIdentifier)]) {
        self.backend=backend;excluded=excludedPIDs
        let directory=Bundle.main.executableURL?.deletingLastPathComponent()
        infrastructurePaths=Set(["Memoria","MemoriaHelper","memoria-worker"].compactMap {directory?.appendingPathComponent($0).path})
    }
    public func excludeInfrastructure(_ pid:Int32) { excluded.insert(pid) }
    public func perform(_ request:TerminationRequest, observationSeconds:Double=2) async -> [TerminationResult] {
        let rejection=ActionPolicy.rejection(for:request,now:ProcessInfo.processInfo.systemUptime,excludedPIDs:excluded,excludedExecutables:infrastructurePaths)
        guard !active, rejection == nil else { return request.targets.map {TerminationResult(target:$0,status:.invalid,message:rejection ?? "Another operation is in progress.")} }
        active=true; defer {active=false}
        var result:[TerminationResult]=[]
        // The caller supplies the reviewed, children-first snapshot. Never expand the scope during execution.
        for target in request.targets {
            if Task.isCancelled { result.append(TerminationResult(target:target,status:.cancelled,message:"Cancelled before signalling."));continue }
            do {
                let current=try await backend.inspect(target.identity.pid)
                guard current.identity == target.identity, current.executable == target.executable else {result.append(TerminationResult(target:target,status:.identityChanged,message:"Identity or executable changed; no signal sent."));continue}
                if current.state == "Zombie" {result.append(TerminationResult(target:target,status:.alreadyExited,message:"Process has exited and is awaiting reaping."));continue}
            } catch {
                let code=Self.code(error)
                result.append(TerminationResult(target:target,status:code == ESRCH ? .alreadyExited:.denied,errorNumber:code,message:code == ESRCH ? "Process already exited.":"Cannot revalidate target; no signal sent. \(error)"));continue
            }
            if Task.isCancelled {result.append(TerminationResult(target:target,status:.cancelled,message:"Cancelled after inspection; no signal sent."));continue}
            // POSIX signalling is PID-based. Revalidation narrows, but cannot eliminate, the final PID/exec TOCTOU window.
            let code=await backend.signal(target.identity.pid,number:request.action.signalNumber)
            guard code == 0 else {
                result.append(TerminationResult(target:target,status:code == ESRCH ? .alreadyExited:(code == EPERM || code == EACCES ? .denied:.failed),errorNumber:code,message:"Signal rejected: \(String(cString:strerror(code))) (\(code)). No protection status is inferred."));continue
            }
            result.append(await observe(target,seconds:min(5,max(0,observationSeconds))))
        }
        return result
    }
    public func quitApplication(_ target:TerminationTarget) async -> TerminationResult {
        guard !excluded.contains(target.identity.pid), !infrastructurePaths.contains(target.executable.path), target.identity.isVerifiable else {return TerminationResult(target:target,status:.invalid,message:"Invalid target.")}
        do {
            let current=try await backend.inspect(target.identity.pid)
            guard current.identity == target.identity, current.executable == target.executable else {return TerminationResult(target:target,status:.identityChanged,message:"Application changed; no quit request sent.")}
            let sent=await MainActor.run {NSRunningApplication(processIdentifier:target.identity.pid)?.terminate() ?? false}
            guard sent else {return TerminationResult(target:target,status:.failed,message:"Application did not accept a normal quit request.")}
            return await observe(target,seconds:3)
        } catch {return TerminationResult(target:target,status:.denied,errorNumber:Self.code(error),message:"Unable to revalidate application: \(error)")}
    }
    private func observe(_ target:TerminationTarget,seconds:Double) async -> TerminationResult {
        let deadline=ProcessInfo.processInfo.systemUptime+seconds
        repeat {
            do {
                let current=try await backend.inspect(target.identity.pid)
                if current.identity != target.identity {return TerminationResult(target:target,status:.exitObserved,message:"Original process exited; PID now belongs to a different process.")}
                if current.state == "Zombie" {return TerminationResult(target:target,status:.exitObserved,message:"Exit observed; awaiting parent reaping.")}
                if current.executable != target.executable {return TerminationResult(target:target,status:.identityChanged,message:"Signal sent; executable changed while observing. No further signal sent.")}
            } catch {
                if Self.code(error) == ESRCH {return TerminationResult(target:target,status:.exitObserved,message:"Exit observed after the request.")}
                return TerminationResult(target:target,status:.requestSent,errorNumber:Self.code(error),message:"Request sent; exit could not be verified: \(error)")
            }
            if Task.isCancelled {return TerminationResult(target:target,status:.requestSent,message:"Request sent; observation cancelled.")}
            do {try await Task.sleep(for:.milliseconds(100))} catch {break}
        } while ProcessInfo.processInfo.systemUptime < deadline
        return TerminationResult(target:target,status:.stillRunning,message:"Request sent; process is still running. No automatic escalation.")
    }
    private static func code(_ error:any Error) -> Int32? {if case InspectionError.system(let code)=error {return code};return nil}
}
public struct FreePortResult:Sendable {
    public let results:[TerminationResult]
    public let scan:PortScan
    public let remaining:[EndpointRecord]
    public let replacements:[EndpointRecord]
}
public actor FreePortCoordinator {
    private let ports:PortCollector
    private let actions:ProcessActionCoordinator
    public init(ports:PortCollector,actions:ProcessActionCoordinator) {self.ports=ports;self.actions=actions}
    public func perform(query:PortQuery, selected:[EndpointRecord], request:TerminationRequest) async -> FreePortResult {
        let scan=await ports.scan(force:true)
        let stillBound=Set(scan.endpoints.filter {query.matches($0,listenersOnly:true)}.map(\.process))
        let confirmed=Set(selected.filter {query.matches($0,listenersOnly:true)}.map(\.process))
        let eligible=request.targets.filter {stillBound.contains($0.identity) && confirmed.contains($0.identity)}
        let rejected=request.targets.filter {!eligible.contains($0)}.map {TerminationResult(target:$0,status:.identityChanged,message:"Selected listener no longer belongs to this target; no signal sent.")}
        let limited=TerminationRequest(targets:eligible,action:request.action,confirmed:request.confirmed,createdMonotonic:request.createdMonotonic,id:request.id)
        let results = eligible.isEmpty ? rejected:await actions.perform(limited)+rejected
        let after=await ports.scan(force:true)
        let remaining=after.endpoints.filter {query.matches($0,listenersOnly:true)}
        return FreePortResult(results:results,scan:after,remaining:remaining,replacements:remaining.filter {!confirmed.contains($0.process)})
    }
}
