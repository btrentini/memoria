import Foundation
import MemoriaCore
import MemoriaCollectors
import MemoriaServices

@main struct Probe {
    static func main() async throws {
        let reader=NativeReader()
        let first=SystemCollector.collect(reader:reader,includeProcesses:true,includeVolumes:true)
        try await Task.sleep(for:.seconds(1))
        let second=SystemCollector.collect(reader:reader,includeProcesses:true,includeVolumes:true)
        let usage=zip(second.cpuTicks,first.cpuTicks).compactMap {$0.delta(from:$1)}
        let ports=await PortCollector().scan(force:true)
        print("OS: \(ProcessInfo.processInfo.operatingSystemVersionString)")
        print("Boot identity available: \(!reader.bootSession.isEmpty)")
        print("CPU cores sampled: \(usage.count); busy: \(usage.isEmpty ? -1:usage.reduce(0){$0+$1.busy}/Double(usage.count))%")
        print("Processes visible: \(second.processes.count); skipped: \(second.skippedProcesses)")
        print("Memory total: \(second.memory?.total ?? 0); interfaces: \(second.interfaces.count); volumes: \(second.volumes.count)")
        print("Endpoints: \(ports.endpoints.count); \(ports.coverage)")
        print("Storage-driver services: \(second.disks.count); with read counters: \(second.disks.filter {$0.readBytes != nil}.count)")
        if let own=try? reader.process(ProcessInfo.processInfo.processIdentifier),
           let detail=try? await ProcessDetailStore().inspect(own) {
            print("Own-process lazy details: \(detail.files.count) visible file paths; signing metadata returned: \(detail.signing.hasPrefix("On-disk"))")
        }
        for error in second.errors {print("Unavailable: \(error)")}
        let coordinator=TelemetryCoordinator()
        for await metrics in await coordinator.samples() {
            if let swap=metrics.first(where:{$0.id=="memory.swap"}) {print("Structured swap metric: \(swap.availability.rawValue), permission \(swap.permission.rawValue), \(swap.error ?? "no error")")}
            await coordinator.stop();break
        }
        guard !usage.isEmpty,second.memory != nil,!second.processes.isEmpty else {throw InspectionError.unavailable("Native probe did not obtain the required measurements")}
    }
}
