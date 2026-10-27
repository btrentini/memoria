import Foundation
import Darwin
import MemoriaCore
import MemoriaCollectors

private final class CancellationFlag:@unchecked Sendable {
    private let lock=NSLock()
    private var cancelled=false
    func cancel() {lock.lock();cancelled=true;lock.unlock()}
    var value:Bool {lock.lock();defer{lock.unlock()};return cancelled}
}
public struct CommandOutput:Sendable {
    public let stdout:Data,stderr:Data
    public let status:Int32
    public let timedOut:Bool,cancelled:Bool,truncated:Bool
}
public final class BoundedCommand:Sendable {
    private let executor=NativeExecutor()
    public init() {}
    public func run(executable:URL, arguments:[String], timeout:Double=5, outputLimit:Int=1_048_576) async throws -> CommandOutput {
        let flag=CancellationFlag()
        return try await withTaskCancellationHandler {
            try await executor.run {
                guard executable.isFileURL,executable.path.hasPrefix("/"),timeout > 0,timeout <= 30,outputLimit > 0,outputLimit <= 4_194_304 else {throw InspectionError.unavailable("Invalid bounded command configuration")}
                let process=Process(),out=Pipe(),err=Pipe()
                process.executableURL=executable;process.arguments=arguments;process.environment=["PATH":"/usr/bin:/bin:/usr/sbin:/sbin","LANG":"C","LC_ALL":"C"]
                process.standardInput=FileHandle.nullDevice;process.standardOutput=out;process.standardError=err
                try process.run()
                try? out.fileHandleForWriting.close();try? err.fileHandleForWriting.close()
                defer {try? out.fileHandleForReading.close();try? err.fileHandleForReading.close()}
                let outFD=out.fileHandleForReading.fileDescriptor,errFD=err.fileHandleForReading.fileDescriptor
                _=fcntl(outFD,F_SETFL,O_NONBLOCK);_=fcntl(errFD,F_SETFL,O_NONBLOCK)
                var stdout=Data(),stderr=Data(),truncated=false,timedOut=false,stopped=false
                let start=ProcessInfo.processInfo.systemUptime
                func drain(_ fd:Int32,_ data:inout Data,_ limit:Int) {
                    var bytes=[UInt8](repeating:0,count:8192)
                    for _ in 0..<32 {
                        let n=Darwin.read(fd,&bytes,bytes.count)
                        guard n > 0 else {break}
                        let available=max(0,limit-data.count)
                        data.append(contentsOf:bytes.prefix(min(n,available)))
                        if n > available {truncated=true;break}
                    }
                }
                while process.isRunning {
                    drain(outFD,&stdout,outputLimit);drain(errFD,&stderr,65536)
                    timedOut=ProcessInfo.processInfo.systemUptime-start >= timeout
                    if timedOut || flag.value || truncated {process.terminate();stopped=true;break}
                    usleep(10_000)
                }
                if stopped {
                    let deadline=ProcessInfo.processInfo.systemUptime+0.2
                    while process.isRunning && ProcessInfo.processInfo.systemUptime < deadline {usleep(10_000)}
                    if process.isRunning {_=Darwin.kill(process.processIdentifier,SIGKILL)}
                }
                process.waitUntilExit();drain(outFD,&stdout,outputLimit);drain(errFD,&stderr,65536)
                return CommandOutput(stdout:stdout,stderr:stderr,status:process.terminationStatus,timedOut:timedOut,cancelled:flag.value,truncated:truncated)
            }
        } onCancel:{flag.cancel()}
    }
}

public struct LsofRecord:Sendable {public var pid:Int32;public var descriptor:Int32;public var family:String;public var transport:Transport;public var local:String;public var remote:String;public var state:String}
public enum LsofParser {
    public static func parse(_ data:Data) -> [LsofRecord] {
        var pid:Int32?,fd:Int32?,family="",transport:Transport?,name="",state="",result:[LsofRecord]=[]
        func flush() {if let pid,let fd,let transport,!name.isEmpty,["IPv4","IPv6"].contains(family) {let addresses=name.components(separatedBy:"->");result.append(LsofRecord(pid:pid,descriptor:fd,family:family,transport:transport,local:addresses[0],remote:addresses.count == 2 ? addresses[1]:"",state:state))};fd=nil;family="";transport=nil;name="";state=""}
        for field in data.split(separator:0) {
            let text=String(decoding:field,as:UTF8.self).trimmingCharacters(in:.newlines)
            guard let key=text.first else {continue}
            let value=String(text.dropFirst())
            switch key {
            case "p":flush();pid=Int32(value)
            case "f":flush();fd=Int32(value.prefix(while:{$0.isNumber}))
            case "t":family=value
            case "P":transport=Transport(rawValue:value)
            case "n":name=value
            case "T":if value.hasPrefix("ST=") {state=String(value.dropFirst(3))}
            default:break
            }
        }
        flush();return result
    }
    static func address(_ text:String) -> (String,UInt16)? {
        guard let colon=text.lastIndex(of:":"),let port=UInt16(text[text.index(after:colon)...]) else {return nil}
        return (String(text[..<colon]).trimmingCharacters(in:CharacterSet(charactersIn:"[]")),port)
    }
}
public actor LsofFallback {
    private let runner=BoundedCommand(),executor=NativeExecutor()
    public init() {}
    public func scan() async throws -> PortScan {
        // lsof's output contains PIDs, not start times. Bind each record to an
        // identity observed before launch and revalidate it after output arrives.
        let before=try await executor.run {
            let reader=NativeReader()
            return Dictionary(try reader.pids().compactMap {pid -> (Int32,ProcessSnapshot)? in
                guard let process=try? reader.process(pid) else {return nil}
                return (pid,process)
            },uniquingKeysWith:{a,_ in a})
        }
        let output=try await runner.run(executable:URL(fileURLWithPath:"/usr/sbin/lsof"),arguments:["-nP","-F0pcftPnT","-iTCP","-iUDP"],timeout:4)
        let records=LsofParser.parse(output.stdout)
        return try await executor.run {
            let reader=NativeReader();var endpoints:[EndpointRecord]=[],failed=0
            for r in records {
                guard let original=before[r.pid],let p=try? reader.process(r.pid),
                      p.identity == original.identity,p.executable == original.executable,
                      let local=LsofParser.address(r.local) else {failed += 1;continue}
                let remote=LsofParser.address(r.remote)
                endpoints.append(EndpointRecord(process:p.identity,executable:p.executable,processName:p.name,descriptor:r.descriptor,family:r.family,transport:r.transport,localAddress:local.0,localPort:local.1,remoteAddress:remote?.0 ?? "",remotePort:remote?.1 ?? 0,state:r.state.isEmpty ? "UDP":r.state))
            }
            // lsof has no complete visibility guarantee, even when it exits successfully.
            return PortScan(endpoints:endpoints,deniedOrRaced:failed+(output.stderr.isEmpty ? 0:1),scanned:Set(records.map(\.pid)).count,truncated:output.truncated || output.timedOut || output.cancelled || output.status > 1)
        }
    }
}
