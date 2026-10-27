import Foundation

public enum TerminationAction: String, Codable, Sendable { case terminate, forceKill
    public var signalNumber:Int32 { self == .terminate ? 15:9 }
    public var title:String { self == .terminate ? "Terminate (SIGTERM)":"Force Kill (SIGKILL)" }
}
public struct TerminationTarget: Codable, Sendable, Equatable, Identifiable {
    public var id:ProcessIdentity { identity }
    public let identity:ProcessIdentity
    public let executable:ExecutableIdentity
    public let name:String
    public init?(process:ProcessSnapshot) {
        guard let executable=process.executable, executable.isVerifiable, process.identity.isVerifiable else { return nil }
        identity=process.identity; self.executable=executable; name=process.name
    }
}
public struct TerminationRequest: Codable, Sendable {
    public let id:UUID
    public let targets:[TerminationTarget]
    public let action:TerminationAction
    public let confirmed:Bool
    public let createdMonotonic:Double
    public init(targets:[TerminationTarget], action:TerminationAction, confirmed:Bool, createdMonotonic:Double=ProcessInfo.processInfo.systemUptime, id:UUID=UUID()) {
        self.id=id; self.targets=targets; self.action=action; self.confirmed=confirmed; self.createdMonotonic=createdMonotonic
    }
}
public enum TerminationStatus:String,Codable,Sendable { case requestSent, exitObserved, alreadyExited, stillRunning, identityChanged, denied, invalid, cancelled, failed }
public struct TerminationResult: Codable, Sendable, Identifiable {
    public var id:ProcessIdentity { target.identity }
    public let target:TerminationTarget
    public let status:TerminationStatus
    public let errorNumber:Int32?
    public let message:String
    public init(target:TerminationTarget,status:TerminationStatus,errorNumber:Int32?=nil,message:String) {self.target=target;self.status=status;self.errorNumber=errorNumber;self.message=message}
}
public enum ActionPolicy {
    public static func rejection(for request:TerminationRequest, now:Double, excludedPIDs:Set<Int32>, excludedExecutables:Set<String> = []) -> String? {
        guard request.confirmed else { return "The selected action and targets have not been confirmed." }
        guard !request.targets.isEmpty, request.targets.count <= 256 else { return "Invalid target count." }
        guard now.isFinite, request.createdMonotonic.isFinite, now >= request.createdMonotonic, now-request.createdMonotonic <= 30 else { return "Confirmation expired. Review the current targets again." }
        guard Set(request.targets.map(\.identity)).count == request.targets.count else { return "Duplicate targets." }
        for target in request.targets {
            guard target.identity.isVerifiable, target.executable.isVerifiable, !excludedPIDs.contains(target.identity.pid), !excludedExecutables.contains(target.executable.path) else { return "Invalid, unverifiable or Memoria infrastructure target." }
        }
        return nil
    }
    public static func command(for target:TerminationTarget, action:TerminationAction) -> String? {
        guard target.identity.isVerifiable, target.executable.isVerifiable else { return nil }
        return "/bin/kill -\(action == .terminate ? "TERM":"KILL") \(target.identity.pid)"
    }
}
public enum ProcessEvent: Sendable {
    case fork(ProcessSnapshot), exec(ProcessSnapshot), exit(ProcessIdentity), gap
}
public struct EventReconciler: Sendable {
    public private(set) var processes:[ProcessIdentity:ProcessSnapshot]=[:]
    public private(set) var requiresPolling=true
    public init() {}
    public mutating func ingest(_ event:ProcessEvent) {
        switch event {
        case .fork(let p),.exec(let p):
            processes=processes.filter {$0.key.pid != p.identity.pid || $0.key == p.identity}
            processes[p.identity]=p
        case .exit(let identity):processes.removeValue(forKey:identity)
        case .gap:requiresPolling=true
        }
    }
    public mutating func reconcile(_ snapshot:[ProcessSnapshot]) { processes=Dictionary(snapshot.map {($0.identity,$0)},uniquingKeysWith: {_,b in b});requiresPolling=false }
}
