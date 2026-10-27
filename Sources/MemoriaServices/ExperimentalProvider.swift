import Foundation
import Security
import Darwin
import MemoriaCore
import MemoriaCollectors

private final class WorkerStop:@unchecked Sendable {
    private let lock=NSLock()
    private var stopped=false
    func stop() {lock.lock();stopped=true;lock.unlock()}
    var value:Bool {lock.lock();defer{lock.unlock()};return stopped}
}
public actor ExperimentalProvider:TelemetryProvider {
    private let executor=NativeExecutor()
    private var task:Task<Void,Never>?
    private var stopFlag:WorkerStop?
    private var state:Availability = .disabled
    private var explanation="Disabled by default"
    public init() {}
    public func capabilities() -> [Capability] {[Capability("experimental","Isolated Apple Silicon worker",tier:.experimental,availability:state,explanation:explanation)]}
    public func samples() -> AsyncStream<[MetricSample]> {
        stop()
        let (stream,continuation)=AsyncStream<[MetricSample]>.makeStream(bufferingPolicy:.bufferingNewest(1))
        let flag=WorkerStop();stopFlag=flag
        continuation.onTermination={_ in flag.stop()}
        guard let team=HelperConfiguration.team,let executable=Bundle.main.url(forAuxiliaryExecutable:"memoria-worker") else {
            state = .unavailable;explanation="A signed, bundled worker with a configured signing team is required.";continuation.finish();return stream
        }
        state = .warmingUp;explanation="Verifying bundled worker"
        let executor=self.executor
        task=Task {[weak self] in
            for attempt in 0..<3 {
                guard !flag.value,!Task.isCancelled else {break}
                do {
                    try await executor.run {try Self.run(executable:executable,team:team,flag:flag,continuation:continuation)}
                    break
                } catch {
                    if flag.value || Task.isCancelled {break}
                    await self?.failed(String(describing:error))
                    if attempt < 2 {try? await Task.sleep(for:.seconds(Double(1 << attempt)))}
                }
            }
            continuation.finish()
        }
        return stream
    }
    private func failed(_ message:String) {state = .failed;explanation=message}
    public func stop() {stopFlag?.stop();task?.cancel();task=nil;stopFlag=nil;state = .disabled;explanation="Disabled"}
    private static func verify(executable:URL,team:String) throws {
        guard team.count == 10,team.allSatisfy({$0.isASCII && ($0.isUppercase || $0.isNumber)}) else {throw InspectionError.unavailable("Invalid signing team")}
        var code:SecStaticCode?,requirement:SecRequirement?
        let text="anchor apple generic and identifier \"fyi.trentini.memoria.worker\" and certificate leaf[subject.OU] = \"\(team)\""
        guard SecStaticCodeCreateWithPath(executable as CFURL,[],&code) == errSecSuccess,
              SecRequirementCreateWithString(text as CFString,[],&requirement) == errSecSuccess,
              let code,let requirement,
              SecStaticCodeCheckValidity(code,SecCSFlags(rawValue:kSecCSStrictValidate),requirement) == errSecSuccess else {throw InspectionError.unavailable("Worker signature verification failed")}
    }
    private static func run(executable:URL,team:String,flag:WorkerStop,continuation:AsyncStream<[MetricSample]>.Continuation) throws {
        try verify(executable:executable,team:team)
        let process=Process(),out=Pipe(),err=Pipe(),control=Pipe()
        process.executableURL=executable;process.arguments=[]
        process.environment=["PATH":"/usr/bin:/bin:/usr/sbin:/sbin","LANG":"C","LC_ALL":"C"]
        process.standardOutput=out;process.standardError=err;process.standardInput=control
        try process.run()
        try? out.fileHandleForWriting.close();try? err.fileHandleForWriting.close();try? control.fileHandleForReading.close()
        let pid=process.processIdentifier
        defer {
            try? control.fileHandleForWriting.close()
            if process.isRunning {
                if getpgid(pid) == pid {_=kill(-pid,SIGTERM)} else {process.terminate()}
                let until=ProcessInfo.processInfo.systemUptime+0.3
                while process.isRunning && ProcessInfo.processInfo.systemUptime < until {usleep(10000)}
                if process.isRunning {if getpgid(pid) == pid {_=kill(-pid,SIGKILL)} else {_=kill(pid,SIGKILL)}}
            }
            process.waitUntilExit()
            try? out.fileHandleForReading.close();try? err.fileHandleForReading.close()
        }
        let stdout=out.fileHandleForReading.fileDescriptor,stderr=err.fileHandleForReading.fileDescriptor
        _=fcntl(stdout,F_SETFL,O_NONBLOCK);_=fcntl(stderr,F_SETFL,O_NONBLOCK)
        var decoder=WorkerDecoder(),handshaken=false,stderrBytes=0,messagesThisSecond=0
        var lastMessage=ProcessInfo.processInfo.systemUptime,windowStart=lastMessage
        var bytes=[UInt8](repeating:0,count:8192)
        while process.isRunning && !flag.value {
            let now=ProcessInfo.processInfo.systemUptime
            if now-lastMessage > (handshaken ? 8:5) {throw InspectionError.unavailable("Worker startup/read deadline exceeded")}
            if now-windowStart >= 1 {messagesThisSecond=0;windowStart=now}
            let count=read(stdout,&bytes,bytes.count)
            if count > 0 {
                let messages=try decoder.feed(Data(bytes.prefix(count)))
                messagesThisSecond += messages.count
                guard messagesThisSecond <= 16 else {throw InspectionError.unavailable("Worker message rate exceeded")}
                for message in messages {
                    lastMessage=now
                    if message.type == "hello" {handshaken=true}
                    if message.type == "error" {throw InspectionError.unavailable(message.error ?? "Worker failed")}
                    if let samples=message.samples {continuation.yield(samples)}
                }
            }
            let errorCount=read(stderr,&bytes,bytes.count)
            if errorCount > 0 {stderrBytes += errorCount}
            guard stderrBytes <= 65536 else {throw InspectionError.unavailable("Worker stderr limit exceeded")}
            usleep(10000)
        }
        if !flag.value {throw InspectionError.unavailable("Worker exited unexpectedly (\(process.terminationStatus))")}
    }
}
