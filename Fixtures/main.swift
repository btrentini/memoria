import Foundation
import Darwin

// Deliberately bounded disposable workloads. Never spawned by the monitoring application.
let args=CommandLine.arguments
guard args.count >= 2 else {print("Usage: MemoriaFixture idle|cpu|memory|ignore-term|server|udp|ipv6 [seconds <= 120] [port or MiB]");exit(2)}
let mode=args[1],seconds=min(120,max(1,args.count > 2 ? Double(args[2]) ?? 10:10))
let deadline=ProcessInfo.processInfo.systemUptime+seconds
if mode == "cpu" {
    FileHandle.standardOutput.write(Data("ready \(getpid()) cpu\n".utf8))
    print(runCPUWorkload(workers:args.count > 3 ? Int(args[3]) ?? 1:1,seconds:seconds))
    exit(0)
}
if mode == "gpu" {
    do {try runMetalWorkload(seconds:seconds);exit(0)} catch {FileHandle.standardError.write(Data("Metal workload failed: \(error)\n".utf8));exit(4)}
}
if mode == "exec" {
    FileHandle.standardOutput.write(Data("ready \(getpid()) exec\n".utf8))
    usleep(500000)
    let executable=strdup("/bin/sleep"),argument=strdup("3")
    var arguments=[executable,argument,nil]
    execv("/bin/sleep",&arguments)
    free(executable);free(argument);exit(5)
}
if mode == "ignore-term" {signal(SIGTERM,SIG_IGN)}
var memory:UnsafeMutableRawPointer?
if mode == "memory" {
    let mib=min(512,max(1,args.count > 3 ? Int(args[3]) ?? 128:128)),size=mib*1024*1024
    memory=malloc(size);if let memory {memset(memory,0xA5,size)}
}
var fd:Int32 = -1
if ["server","udp","ipv6"].contains(mode) {
    let ipv6=mode == "ipv6",udp=mode == "udp",port=UInt16(args.count > 3 ? args[3]:"8080") ?? 8080
    fd=socket(ipv6 ? AF_INET6:AF_INET,udp ? SOCK_DGRAM:SOCK_STREAM,0)
    var yes:Int32=1;_=setsockopt(fd,SOL_SOCKET,SO_REUSEADDR,&yes,socklen_t(MemoryLayout<Int32>.size))
    let result:Int32
    if ipv6 {
        var addr=sockaddr_in6();addr.sin6_len=UInt8(MemoryLayout<sockaddr_in6>.size);addr.sin6_family=sa_family_t(AF_INET6);addr.sin6_port=port.bigEndian;addr.sin6_addr=in6addr_loopback
        result=withUnsafePointer(to:&addr) {$0.withMemoryRebound(to:sockaddr.self,capacity:1){bind(fd,$0,socklen_t(MemoryLayout<sockaddr_in6>.size))}}
    } else {
        var addr=sockaddr_in();addr.sin_len=UInt8(MemoryLayout<sockaddr_in>.size);addr.sin_family=sa_family_t(AF_INET);addr.sin_port=port.bigEndian;addr.sin_addr.s_addr=inet_addr("127.0.0.1")
        result=withUnsafePointer(to:&addr) {$0.withMemoryRebound(to:sockaddr.self,capacity:1){bind(fd,$0,socklen_t(MemoryLayout<sockaddr_in>.size))}}
    }
    guard fd >= 0,result == 0,udp || listen(fd,8) == 0 else {perror("fixture socket");exit(3)}
}
FileHandle.standardOutput.write(Data("ready \(getpid()) \(mode)\n".utf8))
var accumulator:Double=0
while ProcessInfo.processInfo.systemUptime < deadline {
    if mode == "cpu" {for i in 1...10000 {accumulator += sqrt(Double(i))}} else {usleep(20000)}
}
if fd >= 0 {close(fd)}
if let memory {free(memory)}
if mode == "cpu" {print(accumulator)}
