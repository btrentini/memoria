import Foundation

public enum SummaryState:String,Codable,Sendable {case captured,paused}
public enum SummaryPressure:String,Codable,Sendable {case normal,warning,critical,unknown}
public enum SummaryFreshness:String,Sendable {case snapshot,stale,paused}
public struct SummaryPoint:Codable,Sendable,Equatable {
    public let date:Date
    public let cpu:Double?
    public init(date:Date,cpu:Double?) {self.date=date;self.cpu=cpu}
}
/// Aggregate-only schema shared with the extension. No process metadata or arguments.
public struct WidgetSummary:Codable,Sendable,Equatable {
    public static let kind="MemoriaSystemWidget"
    public static let maxBytes=32_768
    public static let staleAfter:TimeInterval=300
    public static let refreshAfter:TimeInterval=900
    public let schema:Int
    public let capturedAt:Date
    public let state:SummaryState
    public let cpuPercent:Double?
    public let accountedMemory,totalMemory:UInt64?
    public let pressure:SummaryPressure
    public let history:[SummaryPoint]
    public init(capturedAt:Date,state:SummaryState = .captured,cpuPercent:Double?,accountedMemory:UInt64?,totalMemory:UInt64?,pressure:SummaryPressure,history:[SummaryPoint]=[],schema:Int=1) {
        self.schema=schema;self.capturedAt=capturedAt;self.state=state;self.cpuPercent=cpuPercent
        self.accountedMemory=accountedMemory;self.totalMemory=totalMemory;self.pressure=pressure;self.history=history
    }
    public var memoryPercent:Double? {
        guard let used=accountedMemory,let total=totalMemory,total>0,used<=total else {return nil}
        return 100*Double(used)/Double(total)
    }
    public var isValid:Bool {
        func validCPU(_ value:Double?) -> Bool {value.map {$0.isFinite && (0...100).contains($0)} ?? true}
        guard schema==1,capturedAt.timeIntervalSince1970.isFinite,capturedAt.timeIntervalSince1970>0,
              validCPU(cpuPercent),history.count<=30,
              totalMemory.map({$0>0 && $0<=(1<<60)}) ?? true,
              accountedMemory.map({$0<=(1<<60)}) ?? true else {return false}
        if let used=accountedMemory,let total=totalMemory,used>total {return false}
        var previous:Date?
        for point in history {
            guard point.date.timeIntervalSince1970.isFinite,point.date<=capturedAt,
                  point.date>=capturedAt.addingTimeInterval(-120),validCPU(point.cpu) else {return false}
            if let previous,point.date<=previous {return false}
            previous=point.date
        }
        if state == .paused {return cpuPercent == nil && accountedMemory == nil && totalMemory == nil && history.isEmpty}
        return true
    }
    public func freshness(at date:Date) -> SummaryFreshness {
        if state == .paused {return .paused}
        let age=date.timeIntervalSince(capturedAt)
        return age.isFinite && age>=(-5) && age<Self.staleAfter ? .snapshot:.stale
    }
    public static func decode(_ data:Data) throws -> Self {
        guard data.count<=maxBytes else {throw SummaryStoreError.tooLarge}
        let result=try JSONDecoder().decode(Self.self,from:data)
        guard result.isValid else {throw SummaryStoreError.invalid}
        return result
    }
    public func encoded() throws -> Data {
        guard isValid else {throw SummaryStoreError.invalid}
        let data=try JSONEncoder().encode(self)
        guard data.count<=Self.maxBytes else {throw SummaryStoreError.tooLarge}
        return data
    }
}
public enum MenuBarReading:String,CaseIterable,Codable,Sendable {
    case both="CPU and memory",cpu="CPU",memory="Memory",icon="Icon only"
    public func text(cpu:Double?,memory:UInt64?,paused:Bool) -> String {
        guard self != .icon else {return ""}
        guard !paused else {return "Paused"}
        let cpuText=cpu.flatMap {$0.isFinite && (0...100).contains($0) ? String(format:"%.0f%%",$0):nil} ?? "—"
        let memoryText=memory.map {String(format:"%.1fG",Double($0)/1_073_741_824)} ?? "—"
        switch self {case .both:return "CPU \(cpuText)  RAM \(memoryText)";case .cpu:return "CPU \(cpuText)";case .memory:return "RAM \(memoryText)";case .icon:return ""}
    }
}
public enum WidgetRoute:String,Sendable {
    case overview,cpu,memory,quick
    public init?(url:URL) {
        guard let parts=URLComponents(url:url,resolvingAgainstBaseURL:false),parts.scheme?.lowercased()=="memoria",
              parts.user==nil,parts.password==nil,parts.port==nil,parts.query==nil,parts.fragment==nil,
              parts.path.isEmpty,let host=parts.host,let route=Self(rawValue:host) else {return nil}
        self=route
    }
    public var url:URL {URL(string:"memoria://"+rawValue)!}
}
