import Foundation

/// Presentation-only memory readings. Never use this cache to authorise actions.
public struct ApplicationMemorySnapshot: Sendable {
    public static let refreshInterval: Double = 300
    public private(set) var monotonic: Double?
    public private(set) var date: Date?
    public private(set) var systemAccounted: UInt64?
    private struct Reading: Sendable {
        let executable: ExecutableIdentity?
        let resident, footprint: UInt64?
    }
    private var readings: [ProcessIdentity: Reading] = [:]
    public init() {}

    @discardableResult
    public mutating func refresh(processes: [ProcessSnapshot], systemAccounted: UInt64?,
                                 monotonic now: Double, date: Date, force: Bool = false) -> Bool {
        guard now.isFinite, now >= 0 else { return false }
        if let previous = monotonic, !force, now >= previous, now - previous < Self.refreshInterval { return false }
        readings = Dictionary(processes.map {
            ($0.identity, Reading(executable: $0.executable, resident: $0.residentBytes, footprint: $0.footprintBytes))
        }, uniquingKeysWith: { _, latest in latest })
        self.monotonic = now; self.date = date; self.systemAccounted = systemAccounted
        return true
    }

    /// Membership, CPU and identity stay live; new or exec-changed processes wait
    /// for the next memory refresh rather than inheriting another executable's RAM.
    public func applying(to processes: [ProcessSnapshot]) -> [ProcessSnapshot] {
        processes.map { process in
            let reading = readings[process.identity].flatMap { $0.executable == process.executable ? $0 : nil }
            return ProcessSnapshot(identity: process.identity, executable: process.executable,
                parentPID: process.parentPID, uid: process.uid, name: process.name, state: process.state,
                threads: process.threads, cpuNanoseconds: process.cpuNanoseconds, cpuPercent: process.cpuPercent,
                residentBytes: reading?.resident, footprintBytes: reading?.footprint,
                diskReadBytes: process.diskReadBytes, diskWriteBytes: process.diskWriteBytes,
                readRate: process.readRate, writeRate: process.writeRate, errors: process.errors,
                observedAt: process.observedAt)
        }
    }
}

/// A fixed review scope, including independently launched helpers in the bundle.
/// Unassigned services are never added, and inferred descendants require opt-in.
public struct ApplicationActionPlan: Sendable {
    public let group: ApplicationGroup
    public let targets: [TerminationTarget]
    public let inferred: Set<ProcessIdentity>
    public let unavailable: [ProcessSnapshot]
    public var defaultSelection: Set<ProcessIdentity> { Set(targets.map(\.identity)).subtracting(inferred) }

    public init(group: ApplicationGroup) {
        self.group = group
        let processes = group.members.map(\.process)
        var seen: Set<ProcessIdentity> = []
        var ordered: [ProcessSnapshot] = []
        for process in processes.sorted(by: { $0.identity.pid < $1.identity.pid }) {
            for member in ProcessTree.descendants(of: process.identity, in: processes) + [process] {
                if seen.insert(member.identity).inserted { ordered.append(member) }
            }
        }
        targets = ordered.compactMap(TerminationTarget.init)
        inferred = Set(group.members.filter { $0.membership == .inferred }.map(\.process.identity))
        unavailable = ordered.filter { TerminationTarget(process: $0) == nil }
    }
}
