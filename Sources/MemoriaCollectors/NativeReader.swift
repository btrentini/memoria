import Foundation
import Darwin
import MemoriaCore
import MemoriaNative

func nativeString<T>(_ value: T) -> String {
    var copy=value
    return withUnsafeBytes(of:&copy) { bytes in String(decoding:bytes.prefix(while:{$0 != 0}),as:UTF8.self) }
}
public enum InspectionError: Error, Sendable, CustomStringConvertible {
    case system(Int32), identityChanged, unavailable(String)
    public var description: String { switch self { case .system(let code): "System error \(code): \(String(cString:strerror(code)))"; case .identityChanged: "Process identity changed"; case .unavailable(let reason): reason } }
}
public struct NativeReader: Sendable {
    public let bootSession: String
    public init() {
        var buffer=[CChar](repeating:0,count:128)
        bootSession = mm_boot_session(&buffer,buffer.count) == 0 ? String(decoding:buffer.prefix(while:{$0 != 0}).map {UInt8(bitPattern:$0)},as:UTF8.self) : ""
    }
    public func pids() throws -> [Int32] {
        var result=[Int32](repeating:0,count:32768)
        let count=mm_list_pids(&result,Int32(result.count))
        guard count >= 0 else { throw InspectionError.system(-count) }
        guard count < result.count else { throw InspectionError.unavailable("Process enumeration exceeded its bounded capacity") }
        return result.prefix(Int(count)).filter {$0 > 0}
    }
    public func process(_ pid: Int32) throws -> ProcessSnapshot {
        var p=mm_process()
        let error=mm_read_process(pid,&p)
        guard error == 0 else { throw InspectionError.system(error) }
        let identity=ProcessIdentity(pid:pid,startSeconds:p.start_seconds,startMicroseconds:p.start_microseconds,bootSession:bootSession)
        let path=nativeString(p.path)
        let executable = p.path_error == 0 && !path.isEmpty ? ExecutableIdentity(path:path,device:p.executable_device,inode:p.executable_inode) : nil
        var errors: [String:Int32]=[:]
        if p.task_error != 0 { errors["task"]=p.task_error }
        if p.resource_error != 0 { errors["resource"]=p.resource_error }
        if p.path_error != 0 { errors["executable"]=p.path_error }
        let state: String = switch p.status { case 1: "Idle"; case 2: "Running"; case 3: "Sleeping"; case 4: "Stopped"; case 5: "Zombie"; default: "Unknown (\(p.status))" }
        return ProcessSnapshot(identity:identity,executable:executable,parentPID:p.parent_pid,uid:p.uid,name:nativeString(p.name),state:state,
                               threads:p.task_error == 0 ? p.threads:nil,cpuNanoseconds:p.task_error == 0 ? p.user_ns &+ p.system_ns:nil,
                               residentBytes:p.task_error == 0 ? p.resident_bytes:nil,footprintBytes:p.resource_error == 0 ? p.footprint_bytes:nil,
                               diskReadBytes:p.resource_error == 0 ? p.disk_read_bytes:nil,diskWriteBytes:p.resource_error == 0 ? p.disk_write_bytes:nil,
                               errors:errors,observedAt:ProcessInfo.processInfo.systemUptime)
    }
    public func arguments(for target: ProcessSnapshot) throws -> [String] {
        guard try process(target.identity.pid).identity == target.identity else { throw InspectionError.identityChanged }
        var bytes=[CChar](repeating:0,count:262144)
        let count=mm_arguments(target.identity.pid,&bytes,bytes.count)
        guard count > MemoryLayout<Int32>.size else { throw InspectionError.system(count < 0 ? -count:EINVAL) }
        let data=bytes.prefix(Int(count)).map {UInt8(bitPattern:$0)}
        let argc = data.withUnsafeBytes { Int($0.loadUnaligned(as:Int32.self)) }
        guard argc >= 0, argc < 32768 else { throw InspectionError.unavailable("Invalid argument count") }
        var offset=MemoryLayout<Int32>.size
        // Skip executable path and padding. Read exactly argc; never read the following environment.
        while offset < data.count && data[offset] != 0 { offset += 1 }
        while offset < data.count && data[offset] == 0 { offset += 1 }
        var result:[String]=[]
        for _ in 0..<argc {
            guard offset < data.count else { throw InspectionError.unavailable("Truncated argument data") }
            let start=offset
            while offset < data.count && data[offset] != 0 { offset += 1 }
            result.append(String(decoding:data[start..<offset],as:UTF8.self)); offset += 1
        }
        let after=try process(target.identity.pid)
        guard after.identity == target.identity && after.executable == target.executable else { throw InspectionError.identityChanged }
        return result
    }
    public func signal(pid: Int32, number: Int32) -> Int32 { mm_send_signal(pid,number) }
}

private final class NativeAdmission:@unchecked Sendable {
    private let lock=NSLock()
    private var count=0
    let limit:Int
    init(_ limit:Int) {self.limit=max(1,min(64,limit))}
    func reserve() -> Bool {lock.lock();defer{lock.unlock()};guard count<limit else{return false};count += 1;return true}
    func release() {lock.lock();count -= 1;lock.unlock()}
    var pending:Int {lock.lock();defer{lock.unlock()};return count}
}
private final class NativeCancellation:@unchecked Sendable {
    private let lock=NSLock()
    private var cancelled=false
    func cancel() {lock.lock();cancelled=true;lock.unlock()}
    var value:Bool {lock.lock();defer{lock.unlock()};return cancelled}
}
/// One running blocking call and a bounded number of admitted calls. Cancellation
/// skips queued work; it cannot interrupt a system call already in progress.
public final class NativeExecutor: Sendable {
    private let queue=DispatchQueue(label:"fyi.trentini.memoria.native",qos:.utility)
    private let admission:NativeAdmission
    public init(maxPending:Int=16) {admission=NativeAdmission(maxPending)}
    public var pendingCount:Int {admission.pending}
    public func run<T: Sendable>(_ operation: @escaping @Sendable () throws -> T) async throws -> T {
        try Task.checkCancellation()
        guard admission.reserve() else {throw InspectionError.unavailable("Native work queue is busy; retry on the next refresh")}
        let flag=NativeCancellation(),admission=self.admission
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation {continuation in
                queue.async {
                    let result:Result<T,any Error>=Result {
                        if flag.value {throw CancellationError()}
                        return try operation()
                    }
                    admission.release()
                    continuation.resume(with:result)
                }
            }
        } onCancel:{flag.cancel()}
    }
}
