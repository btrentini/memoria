import Foundation
import Security
import ServiceManagement
import MemoriaCore
import MemoriaCollectors

@objc public protocol MemoriaHelperProtocol {
    func perform(_ request:Data, authorization:Data, reply:@escaping @Sendable (Data)->Void)
    func ping(_ reply:@escaping @Sendable (Int)->Void)
    func cancel(_ requestID:String, reply:@escaping @Sendable (Bool)->Void)
}
public enum HelperConfiguration {
    public static let identifier="fyi.trentini.memoria.helper"
    public static let appIdentifier="fyi.trentini.memoria"
    public static let plistName="fyi.trentini.memoria.helper.plist"
    public static let protocolVersion=1
    public static var team:String? {
        guard let value=Bundle.main.object(forInfoDictionaryKey:"MemoriaSigningTeam") as? String,
              value.count == 10,value.allSatisfy({$0.isASCII && ($0.isUppercase || $0.isNumber)}) else {return nil}
        return value
    }
    public static func requirement(identifier:String,team:String) -> String? {
        guard [self.identifier,appIdentifier].contains(identifier),team.count == 10,team.allSatisfy({$0.isASCII && ($0.isUppercase || $0.isNumber)}) else {return nil}
        return "anchor apple generic and identifier \"\(identifier)\" and certificate leaf[subject.OU] = \"\(team)\""
    }
}
public struct HelperEnvelope:Codable,Sendable {
    public let version:Int
    public let request:TerminationRequest
    public init(request:TerminationRequest,version:Int=1) {self.request=request;self.version=version}
}
public struct HelperReply:Codable,Sendable {
    public let version:Int
    public let results:[TerminationResult]
    public let error:String?
    public init(results:[TerminationResult]=[],error:String?=nil) {version=1;self.results=results;self.error=error}
}
public struct HelperReplayPolicy:Sendable {
    private var used:[UUID:Double]=[:]
    public init() {}
    public mutating func accept(_ envelope:HelperEnvelope, now:Double, excluded:Set<Int32>) -> String? {
        used=used.filter {now-$0.value <= 60}
        guard envelope.version == HelperConfiguration.protocolVersion else {return "Incompatible helper protocol"}
        guard envelope.request.targets.count == 1 else {return "Administrator requests must authorise exactly one target"}
        if let error=ActionPolicy.rejection(for:envelope.request,now:now,excludedPIDs:excluded) {return error}
        guard used[envelope.request.id] == nil,used.count < 128 else {return "Repeated request or request limit reached"}
        used[envelope.request.id]=now;return nil
    }
}
public enum AdministratorAuthorization {
    private static let right="system.privilege.admin"
    public static func validate(_ data:Data) -> Bool {
        guard data.count == MemoryLayout<AuthorizationExternalForm>.size else {return false}
        var form=AuthorizationExternalForm()
        withUnsafeMutableBytes(of:&form) {$0.copyBytes(from:data)}
        var reference:AuthorizationRef?
        guard AuthorizationCreateFromExternalForm(&form,&reference) == errAuthorizationSuccess,let reference else {return false}
        defer {AuthorizationFree(reference,[])}
        return check(reference,flags:[]) == errAuthorizationSuccess
    }
    @MainActor public static func request() throws -> (AuthorizationRef,Data) {
        var reference:AuthorizationRef?
        let status=AuthorizationCreate(nil,nil,[],&reference)
        guard status == errAuthorizationSuccess,let reference else {throw InspectionError.unavailable("Authorisation unavailable (\(status))")}
        let granted=check(reference,flags:[.interactionAllowed,.extendRights])
        guard granted == errAuthorizationSuccess else {AuthorizationFree(reference,[]);throw InspectionError.unavailable("Administrator authorisation denied (\(granted))")}
        var form=AuthorizationExternalForm()
        guard AuthorizationMakeExternalForm(reference,&form) == errAuthorizationSuccess else {AuthorizationFree(reference,[]);throw InspectionError.unavailable("Could not externalise authorisation")}
        return (reference,withUnsafeBytes(of:&form){Data($0)})
    }
    private static func check(_ reference:AuthorizationRef,flags:AuthorizationFlags) -> OSStatus {
        right.withCString {name in
            var item=AuthorizationItem(name:name,valueLength:0,value:nil,flags:0)
            return withUnsafeMutablePointer(to:&item) {p in
                var rights=AuthorizationRights(count:1,items:p)
                return AuthorizationCopyRights(reference,&rights,nil,flags,nil)
            }
        }
    }
}
public actor HelperRequestHandler {
    private var replay=HelperReplayPolicy()
    private let actions=ProcessActionCoordinator()
    private let executor=NativeExecutor()
    private var pending:[UUID:Task<[TerminationResult],Never>]=[:]
    private var audit:[HelperAuditRecord]=[]
    public init() {}
    public func handle(_ data:Data,authorization:Data) async -> Data {
        func encode(_ value:HelperReply) -> Data {(try? JSONEncoder().encode(value)) ?? Data()}
        guard HelperConfiguration.team != nil else {return encode(HelperReply(error:"Signing team is not configured"))}
        guard data.count <= 65536,authorization.count == MemoryLayout<AuthorizationExternalForm>.size else {return encode(HelperReply(error:"Malformed request"))}
        guard let envelope=try? JSONDecoder().decode(HelperEnvelope.self,from:data) else {return encode(HelperReply(error:"Invalid typed request"))}
        if let error=replay.accept(envelope,now:ProcessInfo.processInfo.systemUptime,excluded:[Int32(ProcessInfo.processInfo.processIdentifier)]) {return encode(HelperReply(error:error))}
        guard pending.count<8 else {return encode(HelperReply(error:"Helper request capacity reached"))}
        let request=envelope.request,actions=self.actions,executor=self.executor
        let task=Task {
            let authorised=(try? await executor.run {AdministratorAuthorization.validate(authorization)}) ?? false
            guard authorised else {return request.targets.map {TerminationResult(target:$0,status:.denied,message:"Missing, expired or revoked administrator authorisation")}}
            return await actions.perform(request)
        }
        pending[request.id]=task
        let results=await task.value
        pending.removeValue(forKey:request.id)
        audit.append(HelperAuditRecord(date:.now,request:request.id,action:request.action,statuses:results.map(\.status)))
        if audit.count>128 {audit.removeFirst(audit.count-128)}
        return encode(HelperReply(results:results))
    }
    public func cancel(_ requestID:String) -> Bool {
        guard requestID.utf8.count==36,let id=UUID(uuidString:requestID),let task=pending[id] else {return false}
        task.cancel();return true
    }
    public func auditSnapshot() -> [HelperAuditRecord] {audit}
}
public struct HelperAuditRecord:Codable,Sendable {
    public let date:Date
    public let request:UUID
    public let action:TerminationAction
    public let statuses:[TerminationStatus]
}
public final class HelperService:NSObject,MemoriaHelperProtocol,Sendable {
    private let handler=HelperRequestHandler()
    public func perform(_ request:Data,authorization:Data,reply:@escaping @Sendable (Data)->Void) {Task {reply(await handler.handle(request,authorization:authorization))}}
    public func ping(_ reply:@escaping @Sendable (Int)->Void) {reply(HelperConfiguration.protocolVersion)}
    public func cancel(_ requestID:String,reply:@escaping @Sendable (Bool)->Void) {Task {reply(await handler.cancel(requestID))}}
}
@MainActor public enum AdministratorService {
    public static var status:String {
        guard HelperConfiguration.team != nil else {return "Unavailable: no configured signing team"}
        switch SMAppService.daemon(plistName:HelperConfiguration.plistName).status {
        case .notRegistered:return "Disabled"
        case .enabled:return "Enabled"
        case .requiresApproval:return "Administrator approval pending in System Settings"
        case .notFound:return "Bundled helper unavailable"
        @unknown default:return "Unknown service state"
        }
    }
    public static func register() throws {
        guard HelperConfiguration.team != nil else {throw InspectionError.unavailable("A signed build with a configured team is required")}
        try SMAppService.daemon(plistName:HelperConfiguration.plistName).register()
    }
    public static func unregister() async throws {try await SMAppService.daemon(plistName:HelperConfiguration.plistName).unregister()}
}
