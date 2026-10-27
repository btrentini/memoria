import SwiftUI
import MemoriaLifecycle
import Charts
import MemoriaStoreMetrics
import MemoriaWidgetSupport

struct StoreDashboard:View {
    @Bindable var model:StoreModel
    var body:some View {
        NavigationSplitView {
            List(StorePage.allCases,selection:$model.selection) {page in
                Label(page.rawValue,systemImage:page.symbol).tag(page)
            }.navigationTitle("Memoria").navigationSplitViewColumnWidth(min:160,ideal:190,max:240)
        } detail: {
            ScrollView {
                VStack(alignment:.leading,spacing:22) {
                    HStack {
                        VStack(alignment:.leading,spacing:5) {
                            Text(model.selection.rawValue).font(.largeTitle.weight(.semibold))
                            Text(model.paused ? "Monitoring paused":"A clear view of your Mac.").foregroundStyle(.secondary)
                        }
                        Spacer()
                        BrandMark(size:32).foregroundStyle(.tint)
                    }
                    if model.selection == .privacy {StorePrivacy()} else {
                        readings
                        if [.overview,.cpu,.memory].contains(model.selection) {
                            GroupBox(model.selection == .memory ? "Accounted memory · last hour":"Whole-machine CPU · last hour") {
                                StoreChart(points:model.history,metric:model.selection == .memory ? .memory:.cpu).frame(height:240).padding(8)
                            }
                        }
                        if !model.simple || [.memory,.network,.power].contains(model.selection) {details}
                        if model.snapshot == nil {
                            Text(model.paused ? "Resume to collect new readings.":"Waiting for the first system sample…").foregroundStyle(.secondary)
                        } else if model.selection == .cpu && model.snapshot?.cpu == nil {
                            Text("CPU rates need two consecutive samples. A gap or counter reset starts a new interval.").font(.callout).foregroundStyle(.secondary)
                        }
                        if let errors=model.snapshot?.errors,!errors.isEmpty {
                            ForEach(errors,id:\.self) {Text($0).font(.caption).foregroundStyle(.secondary)}
                        }
                    }
                }.padding(28).frame(maxWidth:1100,alignment:.leading)
            }.background(.background)
            .toolbar {
                Toggle("Simple view",isOn:$model.simple).toggleStyle(.switch)
                Button(model.paused ? "Resume":"Pause",systemImage:model.paused ? "play.fill":"pause.fill") {model.togglePaused()}
            }
        }.frame(minWidth:820,minHeight:580)
    }
    private var readings:some View {
        LazyVGrid(columns:[GridItem(.adaptive(minimum:180),spacing:14)],spacing:14) {
            StoreReading(title:"CPU",value:storePercent(model.snapshot?.cpu),symbol:"cpu")
            StoreReading(title:"Accounted memory",value:storeBytes(model.snapshot?.memory?.accounted),symbol:"memorychip")
            StoreReading(title:"Memory pressure",value:model.paused ? "—":model.pressure.rawValue.capitalized,symbol:"gauge.with.needle")
            StoreReading(title:"Thermal state",value:model.snapshot?.thermal ?? "—",symbol:"thermometer.medium")
        }
    }
    @ViewBuilder private var details:some View {
        if [.overview,.memory].contains(model.selection) {
            GroupBox("Memory accounting") {
                Grid(alignment:.leading,horizontalSpacing:30,verticalSpacing:10) {
                    memoryRow("Physical RAM",model.snapshot?.memory?.total)
                    memoryRow("Active",model.snapshot?.memory?.active)
                    memoryRow("Wired",model.snapshot?.memory?.wired)
                    memoryRow("Compressed",model.snapshot?.memory?.compressed)
                    memoryRow("Inactive",model.snapshot?.memory?.inactive)
                    memoryRow("Free",model.snapshot?.memory?.free)
                }.padding(12).frame(maxWidth:.infinity,alignment:.leading)
                Text("Accounted memory = active + wired + compressed. Free memory is one component, not all memory available for reuse. Pressure is reported separately by macOS.").font(.caption).foregroundStyle(.secondary).padding(8)
            }
        }
        if [.overview,.network].contains(model.selection) {
            GroupBox("Interface traffic") {
                if let interfaces=model.snapshot?.interfaces,!interfaces.isEmpty {
                    Grid(alignment:.leading,horizontalSpacing:24,verticalSpacing:12) {
                        GridRow {Text("Interface");Text("Type");Text("Receive/s");Text("Send/s")}.fontWeight(.medium)
                        ForEach(interfaces) {item in
                            GridRow {Text(item.name);Text(item.kind).foregroundStyle(.secondary);Text(rate(item.receiveRate));Text(rate(item.sendRate))}.monospacedDigit()
                        }
                    }.font(.callout).padding(12).frame(maxWidth:.infinity,alignment:.leading)
                } else {Text("Interface readings are unavailable.").padding()}
                Text("Interfaces are shown separately. Physical, tunnel and virtual traffic is not added together, because the same traffic may appear more than once.").font(.caption).foregroundStyle(.secondary).padding(8)
            }
        }
        if [.overview,.power].contains(model.selection) {
            GroupBox("Battery and power") {
                VStack(alignment:.leading,spacing:10) {
                    if let battery=model.snapshot?.battery {
                        Text(storePercent(battery.percent)).font(.title2).monospacedDigit()
                        Text(battery.charging ? "Charging":battery.source)
                    } else {Text("No internal battery reading is available on this Mac.")}
                    Text("Thermal state: "+(model.snapshot?.thermal ?? "—"))
                    Text("Thermal state is an operating-system signal, not a temperature reading.").font(.caption).foregroundStyle(.secondary)
                }.padding(12).frame(maxWidth:.infinity,alignment:.leading)
            }
        }
    }
    private func memoryRow(_ title:String,_ value:UInt64?) -> some View {GridRow {Text(title);Text(storeBytes(value)).monospacedDigit()}}
    private func rate(_ value:Double?) -> String {
        guard let value,value.isFinite,value>=0,value<Double(UInt64.max) else {return "—"}
        return storeBytes(UInt64(value))
    }
}
struct StoreReading:View {
    let title:String,value:String,symbol:String
    var body:some View {
        VStack(alignment:.leading,spacing:12) {
            Label(title,systemImage:symbol).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title2.weight(.semibold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
        }.frame(maxWidth:.infinity,alignment:.leading).padding(18).background(.quaternary.opacity(0.4),in:RoundedRectangle(cornerRadius:16))
    }
}
struct StoreChart:View {
    enum Metric {case cpu,memory}
    let points:[StoreHistoryPoint],metric:Metric
    private struct Point:Identifiable {let id:Date,value:Double,segment:Int}
    private var plot:[Point] {
        var result:[Point]=[],segment=0,last:Date?
        for point in points {
            if let last,point.date.timeIntervalSince(last)>15 {segment += 1};last=point.date
            guard let value=(metric == .cpu ? point.cpu:point.memory) else {segment += 1;continue}
            result.append(Point(id:point.date,value:value,segment:segment))
        }
        return result
    }
    var body:some View {
        Chart(plot) {point in
            LineMark(x:.value("Time",point.id),y:.value("Percent",point.value),series:.value("Interval",point.segment)).foregroundStyle(Color.accentColor)
        }.chartYScale(domain:0...100).chartYAxis {AxisMarks(values:[0,50,100])}.chartLegend(.hidden)
            .accessibilityLabel(metric == .cpu ? "Whole-machine CPU percentage history":"Accounted memory percentage history")
    }
}
struct StoreSettings:View {
    @Bindable var model:StoreModel
    @Bindable var lifecycle:BackgroundLifecycle
    var body:some View {
        Form {
            BackgroundPreferences(lifecycle:lifecycle)
            Section("Monitoring") {
                Picker("Sampling interval",selection:$model.interval) {Text("2 seconds").tag(2.0);Text("5 seconds").tag(5.0)}
                Picker("Menu bar",selection:$model.menuReading) {ForEach(MenuBarReading.allCases,id:\.self) {Text($0.rawValue).tag($0)}}
                Toggle("Use simplified view",isOn:$model.simple)
            }
            Section("Desktop widgets") {
                Toggle("Share aggregate readings with widgets",isOn:$model.shareWidget)
                Text(model.widgetStatus).font(.caption).foregroundStyle(.secondary)
                Text("Widgets show a timestamped snapshot. Keep Memoria running for updates; macOS controls when widgets refresh. Switching sharing off deletes the cached snapshot.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Privacy") {StorePrivacy()}
        }.formStyle(.grouped).padding().frame(minHeight:470)
    }
}
struct StorePrivacy:View {
    var body:some View {
        VStack(alignment:.leading,spacing:14) {
            Text("Your readings stay on your Mac.").font(.headline)
            Text("Memoria has no accounts, analytics, advertising, tracking or remote telemetry. System readings are processed locally. Up to one hour of chart history is kept in memory and cleared when you quit.")
            Text("Settings are saved in the app’s private container. If you enable desktop widgets, an aggregate CPU and memory snapshot is written to the app’s shared local container. Turning sharing off deletes that snapshot; macOS may retain a displayed widget until its next refresh.")
            Text("This edition monitors system resources. It does not inspect process arguments, terminate applications, install privileged services or collect private sensor readings.")
        }.font(.callout).foregroundStyle(.secondary).frame(maxWidth:.infinity,alignment:.leading)
    }
}
