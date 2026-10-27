import Foundation
import Security
import MemoriaCore
import MemoriaCollectors

private final class ReplyGate<Value:Sendable>:@unchecked Sendable {
    private let lock=NSLock()
    private var continuation:CheckedContinuation<Value,any Error>?
    init(_ continuation:CheckedContinuation<Value,any Error>) {self.continuation=continuation}
    func resolve(_ result:Result<Value,any Error>) {
        lock.lock();let target=continuation;continuation=nil;lock.unlock()
        target?.resume(with:result)
    }
}
@MainActor private final class HelperConnectionSession {
    let connection:NSXPCConnection
    init(_ connection:NSXPCConnection) {self.connection=connection}
    func cancel(_ id:UUID) {
        if let proxy=connection.remoteObjectProxyWithErrorHandler({_ in}) as? MemoriaHelperProtocol {proxy.cancel(id.uuidString) {_ in}}
    }
}
@MainActor public enum AdministratorClient {
    public static func perform(_ request:TerminationRequest) async throws -> HelperReply {
        guard request.targets.count == 1,request.confirmed,let team=HelperConfiguration.team,
              let requirement=HelperConfiguration.requirement(identifier:HelperConfiguration.identifier,team:team) else {
            throw InspectionError.unavailable("Signed administrator configuration and a confirmed single target are required")
        }
        let connection=NSXPCConnection(machServiceName:HelperConfiguration.identifier,options:.privileged)
        connection.setCodeSigningRequirement(requirement)
        connection.remoteObjectInterface=NSXPCInterface(with:MemoriaHelperProtocol.self)
        let session=HelperConnectionSession(connection)
        connection.resume();defer{connection.invalidate()}
        // Authenticate a reply before sending the transient authorisation form.
        let version:Int=try await withCheckedThrowingContinuation {continuation in
            let gate=ReplyGate(continuation)
            DispatchQueue.global().asyncAfter(deadline:.now()+5) {gate.resolve(.failure(InspectionError.unavailable("Helper handshake timed out")))}
            guard let proxy=connection.remoteObjectProxyWithErrorHandler({gate.resolve(.failure($0))}) as? MemoriaHelperProtocol else {gate.resolve(.failure(InspectionError.unavailable("Helper protocol unavailable")));return}
            proxy.ping {gate.resolve(.success($0))}
        }
        guard version == HelperConfiguration.protocolVersion else {throw InspectionError.unavailable("Helper upgrade required: protocol mismatch")}
        try Task.checkCancellation()
        let (authorization,form)=try AdministratorAuthorization.request()
        defer {AuthorizationFree(authorization,[.destroyRights])}
        let encoded=try JSONEncoder().encode(HelperEnvelope(request:request))
        let response:Data=try await withTaskCancellationHandler {
          try await withCheckedThrowingContinuation {continuation in
            let gate=ReplyGate(continuation)
            DispatchQueue.global().asyncAfter(deadline:.now()+10) {gate.resolve(.failure(InspectionError.unavailable("Helper operation timed out; outcome may be unknown")))}
            guard let proxy=connection.remoteObjectProxyWithErrorHandler({gate.resolve(.failure($0))}) as? MemoriaHelperProtocol else {gate.resolve(.failure(InspectionError.unavailable("Helper connection unavailable")));return}
            proxy.perform(encoded,authorization:form) {gate.resolve(.success($0))}
          }
        } onCancel: {
            Task {@MainActor in session.cancel(request.id)}
        }
        guard response.count <= 65536 else {throw InspectionError.unavailable("Oversized helper response")}
        let reply=try JSONDecoder().decode(HelperReply.self,from:response)
        guard reply.version == HelperConfiguration.protocolVersion else {throw InspectionError.unavailable("Invalid helper reply version")}
        return reply
    }
}
