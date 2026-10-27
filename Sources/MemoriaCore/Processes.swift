import Foundation

public struct ProcessIdentity: Hashable, Codable, Sendable, Identifiable {
    public let pid: Int32
    public let startSeconds, startMicroseconds: UInt64
    public let bootSession: String
    public var id: Self { self }
    public init(pid: Int32, startSeconds: UInt64, startMicroseconds: UInt64, bootSession: String) {
        self.pid = pid; self.startSeconds = startSeconds; self.startMicroseconds = startMicroseconds; self.bootSession = bootSession
    }
    public var isVerifiable: Bool { pid > 1 && startSeconds > 0 && startMicroseconds < 1_000_000 && !bootSession.isEmpty }
}
public struct ExecutableIdentity: Hashable, Codable, Sendable {
    public let path: String
    public let device, inode: UInt64
    public init(path: String, device: UInt64, inode: UInt64) { self.path = path; self.device = device; self.inode = inode }
    public var isVerifiable: Bool { path.hasPrefix("/") && inode != 0 }
}
public struct ProcessSnapshot: Codable, Sendable, Identifiable {
    public var id: ProcessIdentity { identity }
    public let identity: ProcessIdentity
    public let executable: ExecutableIdentity?
    public let parentPID: Int32
    public let uid: UInt32
    public let name: String
    public let state: String
    public let threads: UInt32?
    public let cpuNanoseconds: UInt64?
    public var cpuPercent: Double?
    public let residentBytes, footprintBytes: UInt64?
    public let diskReadBytes, diskWriteBytes: UInt64?
    public var readRate, writeRate: Double?
    public let errors: [String: Int32]
    public let observedAt: Double
    public init(identity: ProcessIdentity, executable: ExecutableIdentity?, parentPID: Int32, uid: UInt32,
                name: String, state: String, threads: UInt32? = nil, cpuNanoseconds: UInt64? = nil, cpuPercent: Double? = nil,
                residentBytes: UInt64? = nil, footprintBytes: UInt64? = nil, diskReadBytes: UInt64? = nil, diskWriteBytes: UInt64? = nil,
                readRate: Double? = nil, writeRate: Double? = nil, errors: [String: Int32] = [:], observedAt: Double = 0) {
        self.identity = identity; self.executable = executable; self.parentPID = parentPID; self.uid = uid; self.name = name
        self.state = state; self.threads = threads; self.cpuNanoseconds = cpuNanoseconds; self.cpuPercent = cpuPercent
        self.residentBytes = residentBytes; self.footprintBytes = footprintBytes; self.diskReadBytes = diskReadBytes; self.diskWriteBytes = diskWriteBytes
        self.readRate = readRate; self.writeRate = writeRate; self.errors = errors; self.observedAt = observedAt
    }
}
public enum Membership: String, Codable, Sendable { case exact, inferred }
public struct ApplicationMember: Codable, Sendable { public let process: ProcessSnapshot; public let membership: Membership }
public struct ApplicationGroup: Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let bundlePath: String
    public let members: [ApplicationMember]
    public var cpuPercent: Double? { let values = members.compactMap(\.process.cpuPercent); return values.isEmpty ? nil : values.reduce(0,+) }
    public var footprintSum: UInt64? { let values = members.compactMap(\.process.footprintBytes); return values.isEmpty ? nil : values.reduce(0,+) }
    public var accountingIncomplete: Bool { members.contains { $0.process.footprintBytes == nil || $0.process.cpuPercent == nil } }
    public init(id: String, name: String, bundlePath: String, members: [ApplicationMember]) { self.id=id; self.name=name; self.bundlePath=bundlePath; self.members=members }
}
public enum ApplicationGrouping {
    public static func bundlePath(_ path: String) -> String? {
        guard let range = path.range(of: ".app/") else { return nil }
        return String(path[..<range.lowerBound]) + ".app"
    }
    public static func group(_ processes: [ProcessSnapshot]) -> [ApplicationGroup] {
        var groups: [String: [ApplicationMember]] = [:]
        let byPID = Dictionary(processes.map { ($0.identity.pid, $0) }, uniquingKeysWith: { a,_ in a })
        for process in processes {
            if let path = process.executable.flatMap({ bundlePath($0.path) }) {
                groups[path, default: []].append(ApplicationMember(process: process, membership: .exact)); continue
            }
            var parent = process.parentPID, visited: Set<Int32> = [process.identity.pid]
            for _ in 0..<32 {
                guard !visited.contains(parent), let ancestor = byPID[parent], ancestor.identity.startSeconds <= process.identity.startSeconds else { break }
                visited.insert(parent)
                if let path = ancestor.executable.flatMap({ bundlePath($0.path) }) {
                    groups[path, default: []].append(ApplicationMember(process: process, membership: .inferred)); break
                }
                parent = ancestor.parentPID
            }
        }
        return groups.map { path,members in
            ApplicationGroup(id: path, name: URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent, bundlePath: path, members: members)
        }.sorted { ($0.cpuPercent ?? -1) > ($1.cpuPercent ?? -1) }
    }
}
public enum ProcessSort: String, CaseIterable, Codable, Sendable {
    case cpu, memory, resident, threads, io, read, write, name, pid, owner, state
    public var title: String {
        switch self {
        case .cpu: "CPU %"; case .memory: "Memory footprint"; case .resident: "Resident memory"
        case .threads: "Threads"; case .io: "Read + write/s"; case .read: "Read/s"; case .write: "Write/s"
        case .name: "Process name"; case .pid: "PID"; case .owner: "Owner UID"; case .state: "State"
        }
    }
    public var isResource: Bool { ![.name, .pid, .owner, .state].contains(self) }
    public func value(in process: ProcessSnapshot) -> Double? {
        let value: Double? = switch self {
        case .cpu: process.cpuPercent
        case .memory: process.footprintBytes.map(Double.init)
        case .resident: process.residentBytes.map(Double.init)
        case .threads: process.threads.map(Double.init)
        case .io: Self.combinedIO(process)
        case .read: process.readRate
        case .write: process.writeRate
        case .name, .pid, .owner, .state: nil
        }
        guard let value, value.isFinite, value >= 0 else { return nil }
        return value
    }
    private static func combinedIO(_ process: ProcessSnapshot) -> Double? {
        guard let read = process.readRate, let write = process.writeRate,
              read.isFinite, write.isFinite, read >= 0, write >= 0 else { return nil }
        return read + write
    }
}
public enum ProcessValueFilter: String, CaseIterable, Codable, Sendable {
    case all = "All values", measured = "Measured values", positive = "Above zero"
}
public struct ProcessFilter: Sendable {
    public var query = ""
    public var uid: UInt32?
    public var state: String?
    public var minimumCPU: Double = 0
    public var minimumMemory: UInt64 = 0
    public var sort: ProcessSort = .cpu
    public var descending = true
    public var values: ProcessValueFilter = .all
    public init() {}
    public func apply(_ processes: [ProcessSnapshot]) -> [ProcessSnapshot] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered = processes.filter { process in
            guard uid == nil || process.uid == uid, state == nil || process.state == state else { return false }
            if minimumCPU > 0, !(ProcessSort.cpu.value(in: process).map { $0 >= minimumCPU } ?? false) { return false }
            if minimumMemory > 0, !(process.footprintBytes.map { $0 >= minimumMemory } ?? false) { return false }
            if sort.isResource, values != .all {
                guard let value = sort.value(in: process), values != .positive || value > 0 else { return false }
            }
            return q.isEmpty || process.name.lowercased().contains(q) || String(process.identity.pid) == q ||
                (process.executable?.path.lowercased().contains(q) ?? false)
        }
        // Nil stays last in both directions. Stable identity ties prevent rows
        // jumping between refreshes when their resource values are equal.
        func ordered<T: Comparable>(_ a: T?, _ b: T?) -> Bool? {
            switch (a, b) {
            case (nil, nil): return nil
            case (nil, _): return false
            case (_, nil): return true
            case let (a?, b?): return a == b ? nil : descending ? a > b : a < b
            }
        }
        return filtered.sorted { a, b in
            let comparison: Bool?
            switch sort {
            case .memory: comparison = ordered(a.footprintBytes, b.footprintBytes)
            case .resident: comparison = ordered(a.residentBytes, b.residentBytes)
            case .threads: comparison = ordered(a.threads, b.threads)
            case .cpu, .io, .read, .write: comparison = ordered(sort.value(in: a), sort.value(in: b))
            case .name, .state:
                let order = (sort == .name ? a.name : a.state).localizedStandardCompare(sort == .name ? b.name : b.state)
                comparison = order == .orderedSame ? nil : descending ? order == .orderedDescending : order == .orderedAscending
            case .pid: comparison = ordered(a.identity.pid, b.identity.pid)
            case .owner: comparison = ordered(a.uid, b.uid)
            }
            if let comparison { return comparison }
            if a.identity.pid != b.identity.pid { return a.identity.pid < b.identity.pid }
            if a.identity.startSeconds != b.identity.startSeconds { return a.identity.startSeconds < b.identity.startSeconds }
            if a.identity.startMicroseconds != b.identity.startMicroseconds { return a.identity.startMicroseconds < b.identity.startMicroseconds }
            return a.identity.bootSession < b.identity.bootSession
        }
    }
}
public enum ProcessTree {
    public static func descendants(of root: ProcessIdentity, in processes: [ProcessSnapshot]) -> [ProcessSnapshot] {
        guard let parent = processes.first(where: { $0.identity == root }) else { return [] }
        var result: [ProcessSnapshot] = [], visited: Set<ProcessIdentity> = [root]
        let children = Dictionary(grouping: processes, by: \.parentPID)
        func visit(_ p: ProcessSnapshot, depth: Int) {
            guard depth < 64 else { return }
            for child in children[p.identity.pid] ?? [] where !visited.contains(child.identity) && child.identity.startSeconds >= p.identity.startSeconds {
                visited.insert(child.identity); visit(child, depth: depth + 1); result.append(child)
            }
        }
        visit(parent, depth: 0); return result
    }
}
