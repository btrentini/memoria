import Foundation
import MemoriaServices

final class ListenerDelegate:NSObject,NSXPCListenerDelegate {
    let service=HelperService()
    func listener(_ listener:NSXPCListener,shouldAcceptNewConnection connection:NSXPCConnection) -> Bool {
        guard let team=HelperConfiguration.team,let requirement=HelperConfiguration.requirement(identifier:HelperConfiguration.appIdentifier,team:team) else {return false}
        connection.setCodeSigningRequirement(requirement)
        connection.exportedInterface=NSXPCInterface(with:MemoriaHelperProtocol.self)
        connection.exportedObject=service
        connection.resume()
        return true
    }
}
guard HelperConfiguration.team != nil else {FileHandle.standardError.write(Data("Memoria helper requires configured signing credentials; refusing to listen.\n".utf8));exit(78)}
let delegate=ListenerDelegate(),listener=NSXPCListener(machServiceName:HelperConfiguration.identifier)
listener.delegate=delegate;listener.resume()
// launchd restarts on demand. A hard lifetime bounds privileged residency and requires fresh authorisation on reconnect.
DispatchQueue.main.asyncAfter(deadline:.now()+60) {exit(0)}
RunLoop.current.run()
