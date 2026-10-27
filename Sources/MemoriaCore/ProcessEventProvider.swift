import Foundation

/// An event source complements polling. Providers must report a gap after loss
/// and must not infer an exit merely from a permission-limited enumeration.
public protocol ProcessEventProvider:Sendable {
    func capabilities() async -> [Capability]
    func events() async -> AsyncStream<ProcessEvent>
    func stop() async
}

/// The stable build has no ES entitlement or system extension to activate.
/// Absence is explicit; consumers continue native polling.
public actor UnavailableEventProvider:ProcessEventProvider {
    public init() {}
    public func capabilities() -> [Capability] {
        [Capability("events","Endpoint Security",tier:.endpointSecurity,availability:.unavailable,
                    explanation:"Apple-approved provisioning and extension approval are required; native polling remains active.")]
    }
    public func events() -> AsyncStream<ProcessEvent> {AsyncStream {$0.finish()}}
    public func stop() {}
}
