import Foundation
import MemoriaCore

public struct TelemetryUpdate: Sendable {
    public let snapshot: NativeSnapshot
    public let metrics: [MetricSample]
    public let pressure: String
}
public actor TelemetryCoordinator: TelemetryProvider {
    private let executor=NativeExecutor()
    private let reader=NativeReader()
    private var previous: NativeSnapshot?
    private var previousProcesses: [ProcessIdentity:ProcessSnapshot]=[:]
    private var currentProcesses:[ProcessSnapshot]=[]
    private var cachedVolumes:[VolumeSnapshot]=[]
    private var loop:Task<Void,Never>?
    private var continuation:AsyncStream<TelemetryUpdate>.Continuation?
    private var metricContinuation:AsyncStream<[MetricSample]>.Continuation?
    private var visible=true, sleeping=false
    private var interval:Double=1
    private var generation=0
    private var pressure="Unknown (no notification received)"
    private var pressureSource:(any DispatchSourceMemoryPressure)?
    private var lastProcessTime:Double = -.infinity, lastVolumeTime:Double = -.infinity
    public init() {}
    public func capabilities() -> [Capability] {
        [Capability("native","CPU, memory, processes, ports and interfaces",tier:.native,availability:.available,explanation:"Mach, libproc and supported host interfaces; individual fields may be denied."),
         Capability("sensors","Apple Silicon sensors",tier:.experimental,availability:.disabled,explanation:"Optional isolated worker. Counter validation is required before enabling measurements."),
         Capability("helper","Administrator operations",tier:.administrator,availability:.disabled,explanation:"Requires signed helper, administrator approval and per-operation authorisation."),
         Capability("events","Process lifecycle events",tier:.endpointSecurity,availability:.unavailable,explanation:"Apple-approved Endpoint Security provisioning is required. Polling remains active."),
         Capability("attribution","Per-process GPU and network",tier:.experimental,availability:.unsupported,explanation:"No validated attribution source is configured."),
         Capability("disk","Storage-driver traffic",tier:.native,availability:.available,explanation:"Documented IOBlockStorageDriver counters, where exposed. Per-service traffic is not summed across volumes. Runtime availability is shown per sample.")]
    }
    public func updates() -> AsyncStream<TelemetryUpdate> {
        continuation?.finish()
        let (stream,c)=AsyncStream<TelemetryUpdate>.makeStream(bufferingPolicy:.bufferingNewest(1)); continuation=c
        c.onTermination={ [weak self] _ in Task { await self?.stop() } }
        start(); return stream
    }
    public func samples() -> AsyncStream<[MetricSample]> {
        metricContinuation?.finish()
        let (stream,c)=AsyncStream<[MetricSample]>.makeStream(bufferingPolicy:.bufferingNewest(1)); metricContinuation=c; start(); return stream
    }
    public func configure(visible:Bool, interval:Double) { self.visible=visible; self.interval=min(10,max(1,interval)) }
    public func setSleeping(_ value:Bool) { sleeping=value; generation += 1; previous=nil; previousProcesses=[:]; currentProcesses=[]; lastProcessTime = -.infinity }
    public func stop() { generation += 1; loop?.cancel(); loop=nil; continuation?.finish(); continuation=nil; metricContinuation?.finish(); metricContinuation=nil; pressureSource?.cancel(); pressureSource=nil; previous=nil; previousProcesses=[:] }
    private func start() {
        guard loop == nil else { return }
        let source=DispatchSource.makeMemoryPressureSource(eventMask:[.normal,.warning,.critical],queue:DispatchQueue.global(qos:.utility))
        source.setEventHandler { [weak self, weak source] in
            guard let data=source?.data else { return }
            let text=data.contains(.critical) ? "Critical" : data.contains(.warning) ? "Warning" : "Normal"
            Task { await self?.setPressure(text) }
        }
        pressureSource=source; source.resume()
        loop=Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { break }
                await self.tick()
                let delay=await self.delay()
                do { try await Task.sleep(for:.seconds(delay)) } catch { break }
            }
        }
    }
    private func setPressure(_ text:String) { pressure=text }
    private func delay() -> Double {
        let thermal=ProcessInfo.processInfo.thermalState
        let onBattery=previous?.battery?.source == "Battery Power"
        return max(interval, sleeping ? 10 : (!visible || onBattery || thermal == .serious || thermal == .critical || ProcessInfo.processInfo.isLowPowerModeEnabled) ? 5:1)
    }
    private func tick() async {
        guard !sleeping else { return }
        let token=generation, now=ProcessInfo.processInfo.systemUptime
        let includeProcesses=now-lastProcessTime >= (visible ? 2:10), includeVolumes=now-lastVolumeTime >= 30
        let reader=self.reader
        guard var snapshot=try? await executor.run({SystemCollector.collect(reader:reader,includeProcesses:includeProcesses,includeVolumes:includeVolumes)}), token == generation, !Task.isCancelled else { return }
        let dt=previous.map { snapshot.monotonic-$0.monotonic } ?? 0
        if let previous, dt > 0 && dt <= 30 && snapshot.cpuTicks.count == previous.cpuTicks.count {
            snapshot.cpu=zip(snapshot.cpuTicks,previous.cpuTicks).map {$0.delta(from:$1)}
            let oldNet=Dictionary(uniqueKeysWithValues:previous.interfaces.map {($0.id,$0)})
            for i in snapshot.interfaces.indices { if let old=oldNet[snapshot.interfaces[i].id] {
                snapshot.interfaces[i].receiveRate=DeltaMath.rate(current:snapshot.interfaces[i].received,previous:old.received,interval:dt)
                snapshot.interfaces[i].sendRate=DeltaMath.rate(current:snapshot.interfaces[i].sent,previous:old.sent,interval:dt)
            }}
            let oldDisks=Dictionary(uniqueKeysWithValues:previous.disks.map {($0.id,$0)})
            for i in snapshot.disks.indices {if let old=oldDisks[snapshot.disks[i].id] {
                if let current=snapshot.disks[i].readBytes,let before=old.readBytes {snapshot.disks[i].readRate=DeltaMath.rate(current:current,previous:before,interval:dt)}
                if let current=snapshot.disks[i].writtenBytes,let before=old.writtenBytes {snapshot.disks[i].writeRate=DeltaMath.rate(current:current,previous:before,interval:dt)}
            }}
        } else { snapshot.cpu=Array(repeating:nil,count:snapshot.cpuTicks.count) }
        if includeProcesses {
            for i in snapshot.processes.indices {
                let p=snapshot.processes[i]
                guard let old=previousProcesses[p.identity], old.executable == p.executable else { continue }
                let interval=p.observedAt-old.observedAt
                guard interval > 0 && interval <= 30 else { continue }
                if let current=p.cpuNanoseconds, let before=old.cpuNanoseconds { snapshot.processes[i].cpuPercent=DeltaMath.processCPU(nanoseconds:current,previous:before,interval:interval) }
                if let current=p.diskReadBytes, let before=old.diskReadBytes { snapshot.processes[i].readRate=DeltaMath.rate(current:current,previous:before,interval:interval) }
                if let current=p.diskWriteBytes, let before=old.diskWriteBytes { snapshot.processes[i].writeRate=DeltaMath.rate(current:current,previous:before,interval:interval) }
            }
            previousProcesses=Dictionary(uniqueKeysWithValues:snapshot.processes.map {($0.identity,$0)}); currentProcesses=snapshot.processes; lastProcessTime=now
        } else { snapshot.processes=currentProcesses }
        if includeVolumes { cachedVolumes=snapshot.volumes; lastVolumeTime=now } else { snapshot.volumes=cachedVolumes }
        let metrics=makeMetrics(snapshot,interval:dt)
        previous=snapshot
        continuation?.yield(TelemetryUpdate(snapshot:snapshot,metrics:metrics,pressure:pressure)); metricContinuation?.yield(metrics)
    }
    private func makeMetrics(_ s:NativeSnapshot, interval:Double) -> [MetricSample] {
        func metric(_ id:String,_ value:Double?,_ unit:MetricUnit,_ api:String,_ type:MeasurementType = .gauge) -> MetricSample {
            let failure=s.metricFailures[id]
            let availability:Availability=value != nil ? .available:failure.map {$0.denied ? .denied:.failed} ?? (type == .intervalDelta && interval<=0 ? .warmingUp:.unavailable)
            return MetricSample(id:id,value:value.map(MetricValue.number),unit:unit,wallTime:s.date,monotonicTime:s.monotonic,interval:interval,api:api,permission:failure?.denied == true ? .denied:value != nil ? .allowed:.unknown,availability:availability,measurement:type,error:failure?.message)
        }
        var result=[metric("cpu.busy",s.systemCPU?.busy,.percent,"host_processor_info",.intervalDelta),
                    metric("memory.accounted",s.memory.map {Double($0.accounted)},.bytes,"host_statistics64",.derived),
                    metric("memory.swap",s.memory?.swapUsed.map(Double.init),.bytes,"sysctl vm.swapusage")]
        for i in s.interfaces {
            result.append(metric("network.\(i.name).receive",i.receiveRate,.bytesPerSecond,"getifaddrs",.intervalDelta))
            result.append(metric("network.\(i.name).send",i.sendRate,.bytesPerSecond,"getifaddrs",.intervalDelta))
        }
        for disk in s.disks {
            result.append(metric("disk.\(disk.id).read",disk.readRate,.bytesPerSecond,"IOBlockStorageDriver Statistics",.intervalDelta))
            result.append(metric("disk.\(disk.id).write",disk.writeRate,.bytesPerSecond,"IOBlockStorageDriver Statistics",.intervalDelta))
        }
        return result
    }
}
