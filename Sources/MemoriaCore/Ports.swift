import Foundation

public enum Transport: String, Codable, Sendable, CaseIterable { case tcp = "TCP", udp = "UDP" }
public struct PortQuery: Equatable, Sendable {
    public let port: UInt16
    public let host: String?
    public let transport: Transport?
    public enum ParseError: Error, Equatable { case invalidFormat, invalidPort, unsupportedScheme }
    public init(_ input: String) throws {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= 2048 else { throw ParseError.invalidFormat }
        var rawPort: String, host: String?, transport: Transport?
        if text.contains("://") {
            guard let components = URLComponents(string:text), let scheme = components.scheme?.lowercased(), ["http","https","tcp","udp"].contains(scheme) else { throw ParseError.unsupportedScheme }
            guard components.user == nil, components.password == nil, let h = components.host, !h.isEmpty else { throw ParseError.invalidFormat }
            // Parse explicit port as text first: URLComponents.port can trap on malformed ports on older Foundation.
            let authority = text.components(separatedBy:"://")[1].split(separator:"/",maxSplits:1).first.map(String.init) ?? ""
            let endpoint = authority.split(separator:"?",maxSplits:1).first.map(String.init) ?? authority
            if let p = endpoint.lastIndex(of:":"), !endpoint.hasSuffix("]") { rawPort = String(endpoint[endpoint.index(after:p)...]).components(separatedBy:"#")[0] }
            else if scheme == "http" { rawPort="80" } else if scheme == "https" { rawPort="443" } else { throw ParseError.invalidPort }
            host = h.trimmingCharacters(in:CharacterSet(charactersIn:"[]")); transport = scheme == "udp" ? .udp : .tcp
        } else {
            var value = text
            let pieces = text.split(separator:"/",omittingEmptySubsequences:false)
            if pieces.count == 2 {
                guard let t = Transport(rawValue:String(pieces[1]).uppercased()) else { throw ParseError.invalidFormat }
                transport=t; value=String(pieces[0])
            } else if pieces.count > 2 { throw ParseError.invalidFormat }
            if value.hasPrefix("[") {
                guard let end = value.firstIndex(of:"]"), value[value.index(after:end)...].hasPrefix(":") else { throw ParseError.invalidFormat }
                host=String(value[value.index(after:value.startIndex)..<end]); rawPort=String(value[value.index(end,offsetBy:2)...])
            } else if let colon = value.lastIndex(of:":") {
                guard value.filter({$0 == ":"}).count == 1 else { throw ParseError.invalidFormat }
                let h=String(value[..<colon]); host=h.isEmpty ? nil : h; rawPort=String(value[value.index(after:colon)...])
            } else { rawPort=value }
        }
        guard !rawPort.isEmpty, rawPort.allSatisfy({ $0.isASCII && $0.isNumber }), let port=UInt16(rawPort), port > 0 else { throw ParseError.invalidPort }
        self.port=port; self.host=host; self.transport=transport
    }
    public func matches(_ endpoint: EndpointRecord, listenersOnly: Bool = false) -> Bool {
        guard endpoint.localPort == port, transport == nil || endpoint.transport == transport else { return false }
        if listenersOnly && !endpoint.isListener { return false }
        guard let host, host != "*" else { return true }
        let any = ["0.0.0.0", "::", "*"].contains(endpoint.localAddress)
        if ["localhost","127.0.0.1","::1"].contains(host.lowercased()) { return any || ["127.0.0.1","::1"].contains(endpoint.localAddress) }
        return any || endpoint.localAddress == host
    }
}
public struct EndpointRecord: Codable, Sendable, Identifiable, Equatable {
    public var id: String { "\(process.pid):\(process.startSeconds):\(descriptor):\(family):\(transport.rawValue):\(localAddress):\(localPort)" }
    public let process: ProcessIdentity
    public let executable: ExecutableIdentity?
    public let processName: String
    public let descriptor: Int32
    public let family: String
    public let transport: Transport
    public let localAddress: String
    public let localPort: UInt16
    public let remoteAddress: String
    public let remotePort: UInt16
    public let state: String
    public var isListener: Bool { transport == .tcp ? state == "LISTEN" : remotePort == 0 }
    public var localDisplay: String { family == "IPv6" ? "[\(localAddress)]:\(localPort)" : "\(localAddress):\(localPort)" }
    public init(process: ProcessIdentity, executable: ExecutableIdentity?, processName: String, descriptor: Int32, family: String, transport: Transport, localAddress: String, localPort: UInt16, remoteAddress: String, remotePort: UInt16, state: String) {
        self.process=process; self.executable=executable; self.processName=processName; self.descriptor=descriptor; self.family=family; self.transport=transport; self.localAddress=localAddress; self.localPort=localPort; self.remoteAddress=remoteAddress; self.remotePort=remotePort; self.state=state
    }
}
public struct PortScan: Sendable {
    public let endpoints: [EndpointRecord]
    public let date: Date
    public let deniedOrRaced: Int
    public let scanned: Int
    public let truncated: Bool
    public var coverage: String { deniedOrRaced == 0 && !truncated ? "Visible processes scanned; visibility remains permission-limited." : "Partial scan: \(deniedOrRaced) inaccessible or changed processes/descriptors\(truncated ? "; scan limit reached" : "")." }
    public init(endpoints: [EndpointRecord], date: Date = .now, deniedOrRaced: Int, scanned: Int, truncated: Bool = false) { self.endpoints=endpoints; self.date=date; self.deniedOrRaced=deniedOrRaced; self.scanned=scanned; self.truncated=truncated }
}
