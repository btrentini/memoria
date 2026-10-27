import SwiftUI
import WidgetKit
import Charts
import MemoriaWidgetSupport

struct MemoriaEntry:TimelineEntry,Sendable {
    let date:Date
    let summary:WidgetSummary?
    let message:String?
}
struct MemoriaProvider:TimelineProvider {
    func placeholder(in context:Context) -> MemoriaEntry {MemoriaEntry(date:.now,summary:nil,message:"Open Memoria")}
    func getSnapshot(in context:Context,completion:@escaping @Sendable (MemoriaEntry)->Void) {
        Task {completion(await entry())}
    }
    func getTimeline(in context:Context,completion:@escaping @Sendable (Timeline<MemoriaEntry>)->Void) {
        Task {
            let first=await entry()
            var entries=[first]
            // This future entry changes only the age label, never inventing measurements.
            if let summary=first.summary,summary.freshness(at:first.date) == .snapshot {
                entries.append(MemoriaEntry(date:summary.capturedAt.addingTimeInterval(WidgetSummary.staleAfter),summary:summary,message:nil))
            }
            completion(Timeline(entries:entries,policy:.after(first.date.addingTimeInterval(WidgetSummary.refreshAfter))))
        }
    }
    private func entry() async -> MemoriaEntry {
        guard let directory=WidgetGroup.directory() else {
            return MemoriaEntry(date:.now,summary:nil,message:"Open a signed Memoria installation to share readings.")
        }
        do {
            let summary=try await SummaryStore(directory:directory).read()
            return MemoriaEntry(date:.now,summary:summary,message:summary == nil ? "Open Memoria to share a snapshot.":nil)
        } catch {return MemoriaEntry(date:.now,summary:nil,message:"Snapshot unavailable. Open Memoria to refresh.")}
    }
}
struct MemoriaWidgetView:View {
    @Environment(\.widgetFamily) private var family
    let entry:MemoriaEntry
    var body:some View {
        VStack(alignment:.leading,spacing:10) {
            HStack {Label {Text("Memoria")} icon:{Image("BrainTemplate").renderingMode(.template).resizable().scaledToFit().frame(width:18,height:18).accessibilityHidden(true)}.font(.caption.weight(.semibold));Spacer();Text(status).font(.caption2).foregroundStyle(.secondary)}
            if let summary=entry.summary {
                if family == .systemMedium {
                    HStack(spacing:20) {
                        Link(destination:WidgetRoute.cpu.url) {reading(title:"CPU",value:percent(summary.cpuPercent),percent:summary.cpuPercent)}
                        Link(destination:WidgetRoute.memory.url) {reading(title:"Accounted memory",value:bytes(summary.accountedMemory),percent:summary.memoryPercent)}
                    }.buttonStyle(.plain)
                    WidgetCPUHistory(points:summary.history)
                } else {
                    reading(title:"CPU",value:percent(summary.cpuPercent),percent:summary.cpuPercent)
                    HStack {Text("Memory").font(.caption).foregroundStyle(.secondary);Spacer();Text(bytes(summary.accountedMemory)).font(.caption.weight(.medium)).monospacedDigit()}
                }
                HStack(spacing:4) {Text("Captured");Text(summary.capturedAt,style:.time);Spacer();if family == .systemMedium {Text("Pressure: "+summary.pressure.rawValue)}}.font(.caption2).foregroundStyle(.secondary)
            } else {
                Spacer(minLength:0)
                Text("CPU —   RAM —").font(.headline).monospacedDigit()
                Text(entry.message ?? "Open Memoria").font(.caption).foregroundStyle(.secondary)
                Spacer(minLength:0)
            }
        }
        .containerBackground(.fill.tertiary,for:.widget)
        .widgetURL(WidgetRoute.overview.url)
        .accessibilityElement(children:.contain)
    }
    private var status:String {
        guard let summary=entry.summary else {return "Unavailable"}
        switch summary.freshness(at:entry.date) {case .snapshot:return "Snapshot";case .stale:return "Last snapshot";case .paused:return "Paused"}
    }
    private func reading(title:String,value:String,percent:Double?) -> some View {
        VStack(alignment:.leading,spacing:4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title2.weight(.semibold)).monospacedDigit().minimumScaleFactor(0.7).lineLimit(1)
            if let percent {ProgressView(value:percent,total:100).tint(.accentColor)}
        }.frame(maxWidth:.infinity,alignment:.leading)
    }
    private func percent(_ value:Double?) -> String {value.map {String(format:"%.0f%%",$0)} ?? "—"}
    private func bytes(_ value:UInt64?) -> String {value.map {ByteCountFormatter.string(fromByteCount:Int64(clamping:$0),countStyle:.memory)} ?? "—"}
}
private struct WidgetCPUHistory:View {
    let points:[SummaryPoint]
    private struct Point:Identifiable {let id:Date,value:Double,segment:Int}
    private var plot:[Point] {
        var result:[Point]=[],segment=0,last:Date?
        for point in points {
            if let last,point.date.timeIntervalSince(last)>12 {segment += 1};last=point.date
            guard let value=point.cpu else {segment += 1;continue}
            result.append(Point(id:point.date,value:value,segment:segment))
        }
        return result
    }
    var body:some View {
        if !plot.isEmpty {
            Chart(plot) {point in
                LineMark(x:.value("Time",point.id),y:.value("CPU %",point.value),series:.value("Segment",point.segment)).foregroundStyle(Color.accentColor)
            }.chartYScale(domain:0...100).chartXAxis(.hidden).chartYAxis(.hidden).frame(height:30)
                .accessibilityLabel("Whole-machine CPU history before the snapshot")
        }
    }
}
struct MemoriaSystemWidget:Widget {
    var body:some WidgetConfiguration {
        StaticConfiguration(kind:WidgetSummary.kind,provider:MemoriaProvider()) {MemoriaWidgetView(entry:$0)}
            .configurationDisplayName("Memoria")
            .description("Timestamped CPU and memory snapshots from Memoria. Keep the app running for new readings.")
            .supportedFamilies([.systemSmall,.systemMedium])
    }
}
@main struct MemoriaWidgetBundle:WidgetBundle {
    var body:some Widget {MemoriaSystemWidget()}
}
