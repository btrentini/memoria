import SwiftUI
import Charts
import MemoriaCore
import MemoriaWidgetSupport

struct MenuBarStatusLabel:View {
    @Bindable var model:AppModel
    private var reading:MenuBarReading {MenuBarReading(rawValue:model.menuBarReading) ?? .both}
    var body:some View {
        HStack(spacing:4) {
            BrandMark()
            if reading != .icon {
                Text(reading.text(cpu:model.snapshot?.systemCPU?.busy,memory:model.snapshot?.memory?.accounted,paused:model.sleeping)).monospacedDigit()
            }
        }.accessibilityLabel(model.sleeping ? "Memoria. Monitoring paused for sleep.":"Memoria. CPU \(model.cpuText). Accounted memory \(Format.bytes(model.snapshot?.memory?.accounted)).")
            .task {model.start()}
    }
}
struct MenuPopover:View {
    @Bindable var model:AppModel
    @Environment(\.openWindow) private var openWindow
    var body:some View {
        VStack(alignment:.leading,spacing:14) {
            HStack {
                Label {Text("Memoria")} icon:{BrandMark()}.font(.headline)
                Spacer()
                SettingsLink {Image(systemName:"gearshape")}.buttonStyle(.plain).help("Settings")
            }
            HStack(spacing:18) {
                VStack(alignment:.leading,spacing:4) {Text("CPU").foregroundStyle(.secondary);Text(model.cpuText).font(.title2).monospacedDigit()}
                Spacer()
                VStack(alignment:.trailing,spacing:4) {Text("Accounted memory").foregroundStyle(.secondary);Text(Format.bytes(model.snapshot?.memory?.accounted)).font(.title2).monospacedDigit()}
            }
            MenuCPUChart(points:model.histories["cpu.busy"]?.downsample(window:60,endingAt:model.snapshot?.monotonic ?? 0,buckets:40) ?? [])
            LabeledContent("Pressure",value:model.update?.pressure ?? "Unknown").font(.caption)
            LabeledContent("Thermal state",value:model.snapshot?.thermal ?? "Unknown").font(.caption)
            Text(model.sleeping ? "Paused for sleep":"CPU is a whole-machine percentage. Memory is active + wired + compressed.").font(.caption2).foregroundStyle(.secondary)
            Divider()
            HStack {
                Button("Open Memoria") {openMain(simple:false)}
                Button("Simple view") {openMain(simple:true)}
            }
            Button("Quick Task Manager") {model.showQuick()}.buttonStyle(.borderedProminent)
            HStack {Text("Desktop widget").font(.caption);Spacer();Button("Set up…") {openWindow(id:"main");NSApp.activate();model.destination = .overview;model.showWidgetHelp=true}.controlSize(.small)}
            Divider()
            Button("Quit Memoria") {NSApp.terminate(nil)}.font(.caption)
        }.padding(18).frame(width:350).task {model.start()}
            .onAppear {model.menuPopoverVisible=true;model.configureSampling()}
            .onDisappear {model.menuPopoverVisible=false;model.configureSampling()}
    }
    private func openMain(simple:Bool) {model.simplifiedView=simple;openWindow(id:"main");NSApp.activate()}
}
private struct MenuCPUChart:View {
    let points:[HistoryPoint]
    private struct Point:Identifiable {let id:Double,date:Date,value:Double,segment:Int}
    private var plot:[Point] {
        var result:[Point]=[],segment=0,last:Double?
        for point in points {
            if let last,point.monotonic-last>12 {segment += 1};last=point.monotonic
            guard let value=point.value else {segment += 1;continue}
            result.append(Point(id:point.monotonic,date:point.date,value:value,segment:segment))
        }
        return result
    }
    var body:some View {
        VStack(alignment:.leading,spacing:5) {
            Text("CPU · last 60 seconds").font(.caption).foregroundStyle(.secondary)
            if plot.isEmpty {Text("Waiting for measurements…").font(.caption).foregroundStyle(.secondary).frame(height:70)}
            else {
                Chart(plot) {point in
                    LineMark(x:.value("Time",point.date),y:.value("CPU %",point.value),series:.value("Segment",point.segment)).foregroundStyle(Color.accentColor)
                }.chartYScale(domain:0...100).chartXAxis(.hidden).chartYAxis {AxisMarks(values:[0,50,100])}.frame(height:70)
            }
        }.accessibilityLabel("Whole-machine CPU history over the last minute")
    }
}
struct WidgetHelpView:View {
    @Bindable var model:AppModel
    @Environment(\.dismiss) private var dismiss
    var body:some View {
        VStack(alignment:.leading,spacing:16) {
            Label("Memoria widgets",systemImage:"rectangle.grid.1x2").font(.title2.weight(.semibold))
            Text("Menu bar: choose CPU, memory or both in Settings → General. Memoria keeps monitoring when its main window is closed. macOS controls the item's position in the status area.")
            Text("Desktop / Notification Centre: open Edit Widgets and search for Memoria. Small and medium sizes show a timestamped CPU and memory snapshot. Keep Memoria running to provide new snapshots; macOS schedules refreshes.")
            Text(model.widgetStatus).font(.callout).foregroundStyle(.secondary)
            Text("Desktop widgets need a signed Memoria installation. Menu-bar monitoring works independently.").font(.caption).foregroundStyle(.secondary)
            HStack {Spacer();Button("Done") {dismiss()}.keyboardShortcut(.defaultAction)}
        }.padding(24).frame(width:500)
    }
}
