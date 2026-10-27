import Foundation
import Darwin
import IOKit.ps
import MemoriaStoreNative

public struct StoreMemory:Sendable {
    public let total,free,active,inactive,wired,compressed:UInt64
    public var accounted:UInt64 {active+wired+compressed}
    public var percent:Double? {total>0 && accounted<=total ? Double(accounted)/Double(total)*100:nil}
}
public struct StoreInterface:Sendable,Identifiable {
    public var id:String {"\(name):\(index)"}
    public let name:String,index:UInt32,kind:String,received:UInt64,sent:UInt64
    public var receiveRate:Double?,sendRate:Double?
}
public struct StoreBattery:Sendable {
    public let percent:Double?,charging:Bool,source:String
}
public struct StoreSnapshot:Sendable {
    public let date:Date,monotonic:Double
    public let ticks:[StoreCPUTicks],memory:StoreMemory?,battery:StoreBattery?,thermal:String
    public var interfaces:[StoreInterface],errors:[String]
    public var cpu:Double?
    public init(date:Date = .now,monotonic:Double,ticks:[StoreCPUTicks],memory:StoreMemory? = nil,battery:StoreBattery? = nil,thermal:String = "Unknown",interfaces:[StoreInterface] = [],errors:[String] = []) {
        self.date=date;self.monotonic=monotonic;self.ticks=ticks;self.memory=memory;self.battery=battery
        self.thermal=thermal;self.interfaces=interfaces;self.errors=errors
    }
}
public struct StoreCPUTicks:Sendable {
    public let user,system,idle,nice:UInt64
    public init(user:UInt64,system:UInt64,idle:UInt64,nice:UInt64=0) {self.user=user;self.system=system;self.idle=idle;self.nice=nice}
    public func delta(from old:Self) -> Double? {
        guard user>=old.user,system>=old.system,idle>=old.idle,nice>=old.nice else {return nil}
        let busy=Double(user-old.user)+Double(system-old.system)+Double(nice-old.nice),total=busy+Double(idle-old.idle)
        return total>0 ? busy/total*100:nil
    }
}
public enum StoreDeltas {
    private static func rate(current:UInt64,previous:UInt64,interval:Double) -> Double? {current>=previous ? Double(current-previous)/interval:nil}
    public static func apply(_ current:StoreSnapshot,previous:StoreSnapshot?) -> StoreSnapshot {
        var result=current
        guard let previous else {return result}
        let interval=current.monotonic-previous.monotonic
        // No CPU or traffic interpolation across suspension or missed intervals.
        guard interval.isFinite,interval>0,interval<=15,current.date.timeIntervalSince(previous.date)>0,
              current.date.timeIntervalSince(previous.date)<=15 else {return result}
        if current.ticks.count == previous.ticks.count,!current.ticks.isEmpty {
            let values=zip(current.ticks,previous.ticks).compactMap {$0.delta(from:$1)}
            if values.count == current.ticks.count {result.cpu=values.reduce(0,+)/Double(values.count)}
        }
        let before=Dictionary(previous.interfaces.map {($0.id,$0)},uniquingKeysWith:{_,last in last})
        result.interfaces=current.interfaces.map {current in
            var value=current
            if let old=before[current.id] {
                value.receiveRate=Self.rate(current:current.received,previous:old.received,interval:interval)
                value.sendRate=Self.rate(current:current.sent,previous:old.sent,interval:interval)
            }
            return value
        }
        return result
    }
}
/// A serial utility queue owns blocking public API reads. No process enumeration,
/// libproc, private sensors, subprocesses, authorisation or network requests.
public final class StoreCollector:Sendable {
    private let queue=DispatchQueue(label:"fyi.trentini.memoria.store.metrics",qos:.utility)
    public init() {}
    public func sample() async -> StoreSnapshot {
        await withCheckedContinuation {continuation in queue.async {continuation.resume(returning:Self.read())}}
    }
    private static func read() -> StoreSnapshot {
        var errors:[String]=[]
        var raw=[ms_cpu](repeating:ms_cpu(),count:256)
        let count=ms_cpu_read(&raw,Int32(raw.count))
        let ticks=count>0 ? raw.prefix(Int(count)).map {StoreCPUTicks(user:$0.user,system:$0.system,idle:$0.idle,nice:$0.nice)}:[]
        if count<=0 {errors.append("CPU statistics unavailable (\(count)).")}
        var bytes=ms_memory();let status=ms_memory_read(&bytes)
        let memory=status==0 ? StoreMemory(total:ProcessInfo.processInfo.physicalMemory,free:bytes.free_bytes,active:bytes.active,inactive:bytes.inactive,wired:bytes.wired,compressed:bytes.compressed):nil
        if status != 0 {errors.append("Memory statistics unavailable (\(status)).")}
        var net=[ms_interface](repeating:ms_interface(),count:256)
        let netCount=ms_interfaces_read(&net,Int32(net.count))
        let interfaces=netCount>=0 ? net.prefix(Int(netCount)).map {raw -> StoreInterface in
            let name=withUnsafeBytes(of:raw.name) {String(decoding:$0.prefix(while:{$0 != 0}),as:UTF8.self)}
            let kind=raw.flags & UInt32(IFF_LOOPBACK) != 0 ? "Loopback":name.hasPrefix("utun") || name.hasPrefix("ipsec") ? "Tunnel":name.hasPrefix("en") ? "Physical":"Virtual"
            return StoreInterface(name:name,index:raw.index,kind:kind,received:raw.received,sent:raw.sent)
        }:[]
        if netCount<0 {errors.append("Interface counters unavailable (\(netCount)).")}
        let thermal:String=switch ProcessInfo.processInfo.thermalState {case .nominal:"Nominal";case .fair:"Fair";case .serious:"Serious";case .critical:"Critical";@unknown default:"Unknown"}
        return StoreSnapshot(monotonic:ProcessInfo.processInfo.systemUptime,ticks:ticks,memory:memory,battery:battery(),thermal:thermal,interfaces:interfaces,errors:errors)
    }
    private static func battery() -> StoreBattery? {
        guard let info=IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),let list=IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else {return nil}
        for source in list {
            guard let value=IOPSGetPowerSourceDescription(info,source)?.takeUnretainedValue() as? [String:Any],value[kIOPSTypeKey] as? String==kIOPSInternalBatteryType else {continue}
            let current=value[kIOPSCurrentCapacityKey] as? Double,maximum=value[kIOPSMaxCapacityKey] as? Double
            let percent=current.flatMap {c in maximum.flatMap {m in m>0 && c>=0 && c<=m ? c/m*100:nil}}
            return StoreBattery(percent:percent,charging:value[kIOPSIsChargingKey] as? Bool ?? false,source:value[kIOPSPowerSourceStateKey] as? String ?? "Unknown")
        }
        return nil
    }
}
