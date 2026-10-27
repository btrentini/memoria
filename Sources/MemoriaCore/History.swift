import Foundation

public struct HistoryPoint: Codable, Sendable, Identifiable, Equatable {
    public var id: Double { monotonic }
    public let date: Date
    public let monotonic: Double
    public let value: Double?
    public init(date: Date, monotonic: Double, value: Double?) { self.date=date; self.monotonic=monotonic; self.value=value?.isFinite == true ? value : nil }
}
public enum HistoryWindow: Int, CaseIterable, Identifiable, Sendable { case minute = 60, fiveMinutes = 300, fifteenMinutes = 900, hour = 3600; public var id: Int { rawValue }
    public var title: String { switch self { case .minute: "60 seconds"; case .fiveMinutes: "5 minutes"; case .fifteenMinutes: "15 minutes"; case .hour: "1 hour" } }
}
public struct BoundedHistory: Sendable {
    public let capacity: Int
    public let retention: Double
    private var storage: [HistoryPoint?]
    private var head = 0
    public private(set) var count = 0
    public init(capacity: Int = 3601, retention: Double = 3600) { self.capacity = max(1,capacity); self.retention = max(1,retention); storage = Array(repeating:nil,count:max(1,capacity)) }
    public mutating func append(_ point: HistoryPoint) {
        if count > 0, let last = storage[(head+count-1)%capacity], point.monotonic <= last.monotonic { return }
        storage[(head+count)%capacity] = point
        if count == capacity { head = (head+1)%capacity } else { count += 1 }
        while count > 1, let first = storage[head], point.monotonic-first.monotonic > retention { storage[head]=nil; head=(head+1)%capacity; count -= 1 }
    }
    public var points: [HistoryPoint] { (0..<count).compactMap { storage[(head+$0)%capacity] } }
    public func downsample(window: Double, endingAt: Double, buckets: Int = 180) -> [HistoryPoint] {
        let input = points.filter { $0.monotonic >= endingAt-window && $0.monotonic <= endingAt }
        guard input.count > buckets, buckets > 0 else { return input }
        let width = window / Double(buckets)
        var result: [HistoryPoint] = [], bucket: [HistoryPoint] = [], index: Int?
        func flush() {
            guard let last = bucket.last else { return }
            if bucket.contains(where: { $0.value == nil }) { result.append(HistoryPoint(date:last.date,monotonic:last.monotonic,value:nil)) }
            else { result.append(HistoryPoint(date:last.date,monotonic:last.monotonic,value:bucket.compactMap(\.value).reduce(0,+)/Double(bucket.count))) }
            bucket.removeAll(keepingCapacity:true)
        }
        for point in input {
            let next = Int((point.monotonic-(endingAt-window))/width)
            if index != next { flush(); index=next }
            bucket.append(point)
        }
        flush(); return result
    }
}
public struct AlertPolicy: Sendable {
    public var high: Double
    public var reset: Double
    public var requiredSamples: Int
    private var consecutive = 0
    public private(set) var active = false
    public init(high: Double, reset: Double, requiredSamples: Int = 3) { self.high=high; self.reset=min(reset,high); self.requiredSamples=max(1,requiredSamples) }
    public mutating func ingest(_ value: Double?) -> Bool {
        guard let value, value.isFinite else { consecutive=0; return false }
        if active { if value <= reset { active=false }; return false }
        consecutive = value >= high ? consecutive+1 : 0
        if consecutive >= requiredSamples { active=true; consecutive=0; return true }
        return false
    }
}
public enum HistoryExport {
    public static func csv(_ metrics: [String:[HistoryPoint]]) -> String {
        var rows = ["metric,time,monotonic_seconds,value"]
        let formatter = ISO8601DateFormatter()
        for key in metrics.keys.sorted() {
            let escaped = "\"" + key.replacingOccurrences(of:"\"",with:"\"\"") + "\""
            for point in metrics[key] ?? [] { rows.append("\(escaped),\(formatter.string(from:point.date)),\(point.monotonic),\(point.value.map(String.init(describing:)) ?? "")") }
        }
        return rows.joined(separator:"\n") + "\n"
    }
}
