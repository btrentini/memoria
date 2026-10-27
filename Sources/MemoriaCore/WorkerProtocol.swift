import Foundation

public struct WorkerMessage:Codable,Sendable {
    public let version:Int
    public let type:String
    public let sequence:UInt64
    public let monotonic:Double
    public let capabilities:[String]?
    public let samples:[MetricSample]?
    public let error:String?
    public init(version:Int=1,type:String,sequence:UInt64,monotonic:Double,capabilities:[String]?=nil,samples:[MetricSample]?=nil,error:String?=nil) {self.version=version;self.type=type;self.sequence=sequence;self.monotonic=monotonic;self.capabilities=capabilities;self.samples=samples;self.error=error}
}
public enum WorkerProtocolError:Error,Equatable {case oversized,invalidVersion,missingHandshake,invalidSequence,invalidTime,invalidMetric,unknownMessage}
public struct WorkerDecoder:Sendable {
    public static let maximumLine=65536
    private var buffer=Data()
    private var handshaken=false
    private var sequence:UInt64?
    private var monotonic:Double?
    private var available:Set<String>=[]
    public init() {}
    public mutating func feed(_ data:Data) throws -> [WorkerMessage] {
        guard data.count <= Self.maximumLine else {throw WorkerProtocolError.oversized}
        var messages:[WorkerMessage]=[]
        for byte in data {
            if byte == 10 {if !buffer.isEmpty {let line=buffer;buffer.removeAll(keepingCapacity:true);messages.append(try decode(line))}}
            else {guard buffer.count < Self.maximumLine else {throw WorkerProtocolError.oversized};buffer.append(byte)}
        }
        return messages
    }
    private mutating func decode(_ data:Data) throws -> WorkerMessage {
        let message=try JSONDecoder().decode(WorkerMessage.self,from:data)
        guard message.version == 1 else {throw WorkerProtocolError.invalidVersion}
        guard message.monotonic.isFinite, message.monotonic >= 0, monotonic.map({message.monotonic >= $0}) ?? true else {throw WorkerProtocolError.invalidTime}
        if !handshaken {
            guard message.type == "hello",message.sequence == 0 else {throw WorkerProtocolError.missingHandshake}
            available=Set(message.capabilities ?? []);handshaken=true
        } else {
            guard let previous=sequence,previous < UInt64.max,message.sequence == previous+1 else {throw WorkerProtocolError.invalidSequence}
            guard ["sample","error","capabilities"].contains(message.type) else {throw WorkerProtocolError.unknownMessage}
            if message.type == "capabilities" {available=Set(message.capabilities ?? [])}
        }
        for sample in message.samples ?? [] {
            guard sample.tier == .experimental, sample.interval.isFinite, sample.interval >= 0, sample.interval <= 30 else {throw WorkerProtocolError.invalidMetric}
            guard sample.monotonicTime.isFinite,abs(sample.monotonicTime-message.monotonic) <= 30 else {throw WorkerProtocolError.invalidTime}
            if sample.availability == .available {
                guard available.contains(sample.id),let value=sample.value?.double,value.isFinite else {throw WorkerProtocolError.invalidMetric}
                let range:ClosedRange<Double> = switch sample.unit {case .percent:0...100;case .ratio:0...1;case .celsius: -20...150;case .rpm:0...20000;case .watts:0...2000;case .megahertz:0...10000;default:0...Double.greatestFiniteMagnitude}
                guard range.contains(value) else {throw WorkerProtocolError.invalidMetric}
            } else if sample.value != nil {throw WorkerProtocolError.invalidMetric}
        }
        sequence=message.sequence;monotonic=message.monotonic;return message
    }
}
