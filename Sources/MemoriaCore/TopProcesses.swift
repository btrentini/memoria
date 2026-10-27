import Foundation

/// A small, independent summary: full-table filters never silently narrow it.
public struct TopProcesses: Sendable {
    public static let limit = 10
    public let metric: ProcessSort
    public let processes: [ProcessSnapshot]
    public let measuredCount: Int
    public let unavailableCount: Int

    public static func rank(_ processes: [ProcessSnapshot], context: ProcessListContext,
                            metric requested: ProcessSort, currentUID: UInt32) -> Self {
        let metric = requested.isResource ? requested : context.defaultSort
        var preferences = ProcessListPreferences(context: context)
        preferences.sort = metric
        let ordered = preferences.apply(to: processes, currentUID: currentUID)
        let measured = ordered.filter { metric.value(in: $0) != nil }
        return Self(metric: metric, processes: Array(measured.prefix(limit)),
                    measuredCount: measured.count, unavailableCount: ordered.count - measured.count)
    }
}
