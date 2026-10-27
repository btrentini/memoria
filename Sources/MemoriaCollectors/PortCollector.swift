import Foundation
import Darwin
import MemoriaCore
import MemoriaNative

public actor PortCollector {
    private let executor=NativeExecutor()
    private let reader=NativeReader()
    private var cached:PortScan?
    private var inFlight:Task<PortScan,Never>?
    public init() {}
    public func scan(force:Bool=false) async -> PortScan {
        if let inFlight { return await inFlight.value }
        if !force, let cached, Date.now.timeIntervalSince(cached.date) < 5 { return cached }
        let reader=self.reader, executor=self.executor
        let task=Task { (try? await executor.run {Self.discover(reader:reader)}) ?? PortScan(endpoints:[],deniedOrRaced:1,scanned:0,truncated:true) }
        inFlight=task; let result=await task.value; inFlight=nil; cached=result; return result
    }
    public static func discover(reader:NativeReader) -> PortScan {
        guard let pids=try? reader.pids() else { return PortScan(endpoints:[],deniedOrRaced:1,scanned:0,truncated:true) }
        var endpoints:[EndpointRecord]=[], denied=0, scanned=0, truncated=false
        let start=ProcessInfo.processInfo.systemUptime
        var sockets=[mm_socket](repeating:mm_socket(),count:4096)
        for pid in pids {
            if ProcessInfo.processInfo.systemUptime-start > 4 || endpoints.count > 32768 { truncated=true; break }
            guard let process=try? reader.process(pid) else { denied += 1; continue }
            var failed:Int32=0
            let count=mm_sockets(pid,&sockets,Int32(sockets.count),&failed)
            guard count >= 0 else { denied += 1; continue }
            guard let after=try? reader.process(pid), after.identity == process.identity, after.executable == process.executable else { denied += 1; continue }
            scanned += 1; denied += Int(failed)
            for s in sockets.prefix(Int(count)) {
                let state:String = switch s.state { case 0:"CLOSED";case 1:"LISTEN";case 2:"SYN_SENT";case 3:"SYN_RECEIVED";case 4:"ESTABLISHED";case 5:"CLOSE_WAIT";case 6:"FIN_WAIT_1";case 7:"CLOSING";case 8:"LAST_ACK";case 9:"FIN_WAIT_2";case 10:"TIME_WAIT";default:s.transport == IPPROTO_UDP ? "UDP":"UNKNOWN" }
                endpoints.append(EndpointRecord(process:process.identity,executable:process.executable,processName:process.name,descriptor:s.fd,family:s.family == AF_INET6 ? "IPv6":"IPv4",transport:s.transport == IPPROTO_TCP ? .tcp:.udp,localAddress:nativeString(s.local_address),localPort:s.local_port,remoteAddress:nativeString(s.remote_address),remotePort:s.remote_port,state:state))
            }
        }
        return PortScan(endpoints:endpoints.sorted {$0.localPort < $1.localPort},deniedOrRaced:denied,scanned:scanned,truncated:truncated)
    }
}
