import Foundation

/// Each dashboard and the quick window retain independent ranking preferences.
public enum ProcessListContext: String, CaseIterable, Codable, Sendable {
    case overview, applications, processes, cpu, memory, gpu, storage, network, ports, power, history, diagnostics, quick
    public var defaultSort: ProcessSort {
        switch self {
        case .memory, .applications: .memory
        case .storage: .io
        default: .cpu
        }
    }
    public var note: String {
        switch self {
        case .gpu: "Per-process GPU and Neural Engine attribution is unavailable. This list ranks the available CPU, memory and I/O measurements."
        case .network: "Per-process network traffic is unavailable. CPU, memory and process I/O rankings do not attribute network bytes."
        case .power: "Per-process energy attribution is unavailable. CPU ranking is not a power measurement."
        case .storage: "Read/write rates are process-accounting deltas, not physical-device traffic. A combined rate requires both measurements."
        case .history: "This ranking uses the latest process snapshot, not the selected historical time window."
        default: "CPU uses one core as 100%. Memory is process footprint, not unique physical RAM."
        }
    }
}
public enum ProcessScope: String, CaseIterable, Codable, Sendable {
    case all = "All processes", mine = "My processes", applications = "Applications", active = "Active CPU"
}
public struct ProcessListPreferences: Codable, Hashable, Sendable {
    public var query = ""
    public var scope: ProcessScope = .all
    public var state = ""
    public var sort: ProcessSort
    public var descending = true
    public var minimumCPU: Double = 0
    public var minimumMemory: UInt64 = 0
    public var values: ProcessValueFilter = .all
    public var showThreads = false
    public var showResident = false
    public var showIO = true
    public var showOwner = true
    public var tree = false
    public init(context: ProcessListContext) {
        sort = context.defaultSort
        if context == .applications { scope = .applications }
    }
    public func apply(to processes: [ProcessSnapshot], currentUID: UInt32, scan: PortScan? = nil) -> [ProcessSnapshot] {
        var filter = ProcessFilter()
        filter.query = query; filter.sort = sort; filter.descending = descending
        filter.minimumCPU = scope == .active ? max(0.1, minimumCPU) : minimumCPU
        filter.minimumMemory = minimumMemory; filter.values = values
        filter.state = state.isEmpty ? nil : state
        if scope == .mine { filter.uid = currentUID }
        var input = processes
        if scope == .applications {
            let members = Set(ApplicationGrouping.group(processes).flatMap { $0.members.map(\.process.identity) })
            input = input.filter { members.contains($0.identity) }
        }
        if let query = try? PortQuery(query), let scan {
            // A numeric query can identify a PID and a port simultaneously.
            // Match full process identities so a stale socket cannot select a replacement PID.
            let direct = Set(filter.apply(input).map(\.identity))
            let sockets = Set(scan.endpoints.filter { query.matches($0) }.map(\.process))
            input = input.filter { direct.contains($0.identity) || sockets.contains($0.identity) }
            filter.query = ""
        }
        return filter.apply(input)
    }
    /// Search text can contain private paths; retain controls without persisting queries.
    public var persisted: Self { var value = self; value.query = ""; return value }
}
