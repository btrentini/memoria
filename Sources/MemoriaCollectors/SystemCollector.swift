import Foundation
import Darwin
import IOKit.ps
import MemoriaCore
import MemoriaNative

public struct MemorySnapshot: Codable, Sendable {
    public let total, free, active, inactive, wired, compressed, purgeable, speculative: UInt64
    public let swapTotal, swapUsed: UInt64?
    public let pageIns, pageOuts, swapIns, swapOuts, pageSize: UInt64
    public var accounted: UInt64 { active + wired + compressed }
}
public enum InterfaceKind: String, Codable, Sendable { case physical, virtual, loopback, tunnel }
public struct InterfaceSnapshot: Codable, Sendable, Identifiable {
    public var id: String { "\(name):\(index)" }
    public let name: String
    public let index: UInt32
    public let kind: InterfaceKind
    public let up: Bool
    public let received, sent: UInt64
    public var receiveRate, sendRate: Double?
}
public struct VolumeSnapshot: Codable, Sendable, Identifiable {
    public var id: String { path }
    public let name, path: String
    public let total, available: Int64?
    public let internalVolume: Bool?
    public let error: String?
}
public struct BatterySnapshot: Codable, Sendable {
    public let percentage: Double?
    public let charging: Bool
    public let source: String
}
public struct NativeMetricFailure:Sendable {
    public let message:String
    public let denied:Bool
}
public struct NativeSnapshot: Sendable {
    public let date: Date
    public let monotonic: Double
    public var cpuTicks: [CPUTicks]
    public var cpu: [CPUUsage?] = []
    public var memory: MemorySnapshot?
    public var load: [Double]
    public var processes: [ProcessSnapshot]
    public var interfaces: [InterfaceSnapshot]
    public var volumes: [VolumeSnapshot]
    public var battery: BatterySnapshot?
    public var thermal: String
    public var errors: [String]
    public var skippedProcesses: Int
    public var disks:[DiskSnapshot]=[]
    public var metricFailures:[String:NativeMetricFailure]=[:]
    public var systemCPU: CPUUsage? {
        let values=cpu.compactMap {$0}; guard !values.isEmpty && values.count == cpu.count else { return nil }
        let n=Double(values.count)
        return CPUUsage(user:values.reduce(0){$0+$1.user}/n,system:values.reduce(0){$0+$1.system}/n,idle:values.reduce(0){$0+$1.idle}/n)
    }
}
public enum SystemCollector {
    public static func collect(reader: NativeReader, includeProcesses: Bool, includeVolumes: Bool) -> NativeSnapshot {
        let now=ProcessInfo.processInfo.systemUptime
        var errors:[String]=[], raw=[mm_cpu_ticks](repeating:mm_cpu_ticks(),count:256)
        let n=mm_cpu(&raw,Int32(raw.count))
        let ticks=n > 0 ? raw.prefix(Int(n)).map { CPUTicks(user:$0.user,system:$0.system,idle:$0.idle,nice:$0.nice) } : []
        if n <= 0 { errors.append("Mach CPU statistics unavailable (\(n))") }
        var m=mm_memory(); let memoryError=mm_read_memory(&m)
        let memory: MemorySnapshot? = memoryError == 0 ? MemorySnapshot(total:m.total,free:m.free_bytes,active:m.active,inactive:m.inactive,wired:m.wired,compressed:m.compressed,purgeable:m.purgeable,speculative:m.speculative,swapTotal:m.swap_error == 0 ? m.swap_total:nil,swapUsed:m.swap_error == 0 ? m.swap_used:nil,pageIns:m.pageins,pageOuts:m.pageouts,swapIns:m.swapins,swapOuts:m.swapouts,pageSize:m.page_size) : nil
        if memoryError != 0 { errors.append("Memory statistics unavailable (\(memoryError))") }
        if m.swap_error != 0 { errors.append("Swap statistics unavailable (\(m.swap_error))") }
        var load=[Double](repeating:0,count:3)
        if getloadavg(&load,3) < 0 { load=[] }
        var processes:[ProcessSnapshot]=[], skipped=0
        if includeProcesses {
            do { for pid in try reader.pids() {
                do { processes.append(try reader.process(pid)) } catch { skipped += 1 }
            }} catch { errors.append(String(describing:error)) }
        }
        var interfaces:[InterfaceSnapshot]=[], net=[mm_interface](repeating:mm_interface(),count:256)
        let netCount=mm_interfaces(&net,Int32(net.count))
        if netCount >= 0 { for i in net.prefix(Int(netCount)) {
            let name=nativeString(i.name)
            let kind: InterfaceKind
            if i.flags & UInt32(IFF_LOOPBACK) != 0 { kind = .loopback }
            else if name.hasPrefix("utun") || name.hasPrefix("ipsec") || name.hasPrefix("ppp") { kind = .tunnel }
            else if name.hasPrefix("en") { kind = .physical }
            else { kind = .virtual }
            interfaces.append(InterfaceSnapshot(name:name,index:i.index,kind:kind,up:i.flags & UInt32(IFF_UP) != 0,received:i.received,sent:i.sent))
        }} else { errors.append("Interface counters unavailable (\(netCount))") }
        let thermal: String = switch ProcessInfo.processInfo.thermalState { case .nominal: "Nominal"; case .fair: "Fair"; case .serious: "Serious"; case .critical: "Critical"; @unknown default: "Unknown" }
        var snapshot=NativeSnapshot(date:.now,monotonic:now,cpuTicks:ticks,memory:memory,load:load,processes:processes,interfaces:interfaces,
                              volumes:includeVolumes ? volumes():[],battery:battery(),thermal:thermal,errors:errors,skippedProcesses:skipped)
        snapshot.disks=DiskCollector.read()
        if n<=0 {snapshot.metricFailures["cpu.busy"]=NativeMetricFailure(message:"Mach CPU status \(n)",denied:false)}
        if memoryError != 0 {snapshot.metricFailures["memory.accounted"]=NativeMetricFailure(message:"Mach VM status \(memoryError)",denied:false)}
        if m.swap_error != 0 {snapshot.metricFailures["memory.swap"]=NativeMetricFailure(message:"sysctl vm.swapusage errno \(m.swap_error)",denied:m.swap_error == EPERM || m.swap_error == EACCES)}
        return snapshot
    }
    public static func volumes() -> [VolumeSnapshot] {
        let keys:Set<URLResourceKey>=[.volumeNameKey,.volumeTotalCapacityKey,.volumeAvailableCapacityKey,.volumeIsInternalKey]
        return (FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys:Array(keys),options:[.skipHiddenVolumes]) ?? []).map { url in
            do { let v=try url.resourceValues(forKeys:keys)
                return VolumeSnapshot(name:v.volumeName ?? url.lastPathComponent,path:url.path,total:v.volumeTotalCapacity.map(Int64.init),available:v.volumeAvailableCapacity.map(Int64.init),internalVolume:v.volumeIsInternal,error:nil)
            } catch { return VolumeSnapshot(name:url.lastPathComponent,path:url.path,total:nil,available:nil,internalVolume:nil,error:String(describing:error)) }
        }
    }
    private static func battery() -> BatterySnapshot? {
        guard let info=IOPSCopyPowerSourcesInfo()?.takeRetainedValue(), let list=IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
        for source in list {
            guard let d=IOPSGetPowerSourceDescription(info,source)?.takeUnretainedValue() as? [String:Any], d[kIOPSTypeKey] as? String == kIOPSInternalBatteryType else { continue }
            let current=d[kIOPSCurrentCapacityKey] as? Double, maximum=d[kIOPSMaxCapacityKey] as? Double
            let percent = current.flatMap { c in maximum.flatMap { $0 > 0 ? c/$0*100:nil } }
            return BatterySnapshot(percentage:percent,charging:d[kIOPSIsChargingKey] as? Bool ?? false,source:d[kIOPSPowerSourceStateKey] as? String ?? "Unknown")
        }
        return nil
    }
}
