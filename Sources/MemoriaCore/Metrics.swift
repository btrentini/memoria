import Foundation

public enum CapabilityTier: Int, Codable, Sendable, CaseIterable { case native = 1, experimental, administrator, endpointSecurity }
public enum Availability: String, Codable, Sendable { case available, warmingUp, unavailable, unsupported, denied, stale, failed, disabled }
public enum PermissionState: String, Codable, Sendable { case notRequired, allowed, denied, unknown, approvalPending }
public enum MeasurementType: String, Codable, Sendable { case counter, gauge, intervalDelta, derived, estimate }
public enum MetricUnit: String, Codable, Sendable { case percent, bytes, bytesPerSecond, seconds, watts, celsius, rpm, megahertz, count, ratio, pagesPerSecond }
public enum MetricValue: Codable, Sendable, Equatable {
    case number(Double), integer(UInt64), text(String)
    public var double: Double? { switch self { case .number(let n): n; case .integer(let n): Double(n); case .text: nil } }
}
public struct MetricSample: Codable, Sendable, Identifiable {
    public var id: String
    public var value: MetricValue?
    public var unit: MetricUnit
    public var wallTime: Date
    public var monotonicTime: TimeInterval
    public var interval: TimeInterval
    public var provider: String
    public var api: String
    public var tier: CapabilityTier
    public var permission: PermissionState
    public var availability: Availability
    public var quality: String
    public var measurement: MeasurementType
    public var error: String?
    public init(id: String, value: MetricValue? = nil, unit: MetricUnit, wallTime: Date = .now,
                monotonicTime: TimeInterval, interval: TimeInterval = 0, provider: String = "Native",
                api: String, tier: CapabilityTier = .native, permission: PermissionState = .notRequired,
                availability: Availability = .available, quality: String = "System accounting", measurement: MeasurementType = .gauge, error: String? = nil) {
        self.id = id; self.value = availability == .available ? value : nil; self.unit = unit
        self.wallTime = wallTime; self.monotonicTime = monotonicTime; self.interval = interval
        self.provider = provider; self.api = api; self.tier = tier; self.permission = permission
        self.availability = availability; self.quality = quality; self.measurement = measurement; self.error = error
    }
}
public struct Capability: Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let tier: CapabilityTier
    public var availability: Availability
    public var explanation: String
    public init(_ id: String, _ name: String, tier: CapabilityTier, availability: Availability, explanation: String) {
        self.id = id; self.name = name; self.tier = tier; self.availability = availability; self.explanation = explanation
    }
}
public protocol TelemetryProvider: Sendable {
    func capabilities() async -> [Capability]
    func samples() async -> AsyncStream<[MetricSample]>
    func stop() async
}
public struct CPUTicks: Sendable, Equatable {
    public var user, system, idle, nice: UInt64
    public init(user: UInt64, system: UInt64, idle: UInt64, nice: UInt64 = 0) { self.user = user; self.system = system; self.idle = idle; self.nice = nice }
    public func delta(from previous: Self) -> CPUUsage? {
        // Reset/wrap is a discontinuity. Do not invent an interval across it.
        guard user >= previous.user, system >= previous.system, idle >= previous.idle, nice >= previous.nice else { return nil }
        let u = Double(user - previous.user) + Double(nice - previous.nice)
        let s = Double(system - previous.system), i = Double(idle - previous.idle), total = u+s+i
        guard total > 0 else { return nil }
        return CPUUsage(user: u/total*100, system: s/total*100, idle: i/total*100)
    }
}
public struct CPUUsage: Codable, Sendable, Equatable {
    public var user, system, idle: Double
    public var busy: Double { user + system }
    public init(user: Double, system: Double, idle: Double) { self.user = user; self.system = system; self.idle = idle }
}
public enum DeltaMath {
    public static func rate(current: UInt64, previous: UInt64, interval: Double) -> Double? {
        guard interval.isFinite, interval > 0, current >= previous else { return nil }
        return Double(current - previous) / interval
    }
    public static func processCPU(nanoseconds: UInt64, previous: UInt64, interval: Double) -> Double? {
        rate(current: nanoseconds, previous: previous, interval: interval).map { $0 / 1_000_000_000 * 100 }
    }
    public static func machineCPU(oneCore: Double, coreCount: Int) -> Double? { coreCount > 0 ? oneCore / Double(coreCount) : nil }
}
