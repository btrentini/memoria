import SwiftUI
import Charts
import AppKit
import MemoriaCore
import MemoriaCollectors
import MemoriaServices

struct MainView:View {
    @Bindable var model:AppModel
    @State private var visibility:NavigationSplitViewVisibility = .all
    var body:some View {
        NavigationSplitView(columnVisibility:$visibility) {
            VStack(alignment:.leading,spacing:24) {
                HStack(spacing:10) {BrandMark(size:24).foregroundStyle(.tint);VStack(alignment:.leading,spacing:1) {Text("Memoria").font(.title3.weight(.semibold));Text("SYSTEM MONITOR").font(.system(size:9,weight:.medium,design:.rounded)).tracking(1.8).foregroundStyle(.secondary)}}.padding(.horizontal,12).padding(.top,20)
                List(Destination.allCases,selection:$model.destination) {destination in Label(destination.rawValue,systemImage:destination.symbol).tag(destination).padding(.vertical,3)}.listStyle(.sidebar)
                VStack(alignment:.leading,spacing:5) {Label(model.sleeping ? "Monitoring paused":"Local monitoring",systemImage:model.sleeping ? "pause.circle":"circle.fill").font(.caption).foregroundStyle(model.sleeping ? Color.secondary:Color.green);Text("\(model.snapshot?.cpuTicks.count ?? 0) logical cores · \(Format.bytes(model.snapshot?.memory?.total))").font(.caption2).foregroundStyle(.secondary)}.padding(16)
            }.navigationSplitViewColumnWidth(min:185,ideal:205,max:260)
        } detail: {
            VStack(spacing:0) {
                HStack(alignment:.firstTextBaseline) {VStack(alignment:.leading,spacing:5) {Text(model.destination.rawValue).font(.largeTitle.weight(.semibold));Text(subtitle).font(.subheadline).foregroundStyle(.secondary)};Spacer();if model.operationRunning {ProgressView().controlSize(.small)}}.padding(24)
                Divider()
                if model.simplifiedView {
                    SimpleDashboardView(model:model,context:model.destination.processContext).id(model.destination)
                } else if model.destination == .processes {
                    ProcessView(model:model,context:.processes)
                } else {
                    VSplitView {
                        content.frame(minHeight:130,idealHeight:300,maxHeight:.infinity)
                        ProcessView(model:model,context:model.destination.processContext)
                            .id(model.destination).frame(minHeight:310,idealHeight:420,maxHeight:.infinity)
                    }
                }
                Divider()
                HStack {Text(model.sleeping ? "Paused for sleep":model.snapshot == nil ? "Waiting for system providers…":"\(model.snapshot?.processes.count ?? 0) visible processes");Spacer();if let date=model.snapshot?.date {Text("Updated \(date.formatted(date:.omitted,time:.standard))")};Text("Tier 1 · Native")}.font(.caption).foregroundStyle(.secondary).padding(.horizontal,20).padding(.vertical,9)
            }.background(Color(nsColor:.windowBackgroundColor))
            .inspector(isPresented:Binding(get:{!model.simplifiedView && model.inspectorVisible},set:{if !model.simplifiedView {model.inspectorVisible=$0}})) {InspectorView(model:model).inspectorColumnWidth(min:250,ideal:285,max:380)}
        }
        .toolbar {
            ToolbarItemGroup {
                Picker("View",selection:$model.simplifiedView) {
                    Text("Full").tag(false);Text("Simple").tag(true)
                }.pickerStyle(.segmented).frame(width:140).accessibilityIdentifier("monitor-view-mode")
                Button {model.showQuick()} label:{Label("Quick Task Manager",systemImage:"bolt.square")}
                Button {model.commandPalette=true} label:{Label("Commands",systemImage:"command")}
                if !model.simplifiedView {Button {model.inspectorVisible.toggle()} label:{Label("Inspector",systemImage:"sidebar.right")}}
            }
        }
        .sheet(item:Binding(get:{model.reviewPresenter == "main" ? model.review:nil},set:{model.review=$0})) {review in ActionConfirmation(model:model,review:review)}
        .sheet(isPresented:$model.showWidgetHelp) {WidgetHelpView(model:model)}
        .sheet(isPresented:$model.commandPalette) {CommandPalette(model:model)}
        .alert("Operation result",isPresented:Binding(get:{model.reviewPresenter == "main" && !model.resultMessage.isEmpty},set:{if !$0 {model.resultMessage=""}})) {Button("OK",role:.cancel) {model.resultMessage=""}} message:{Text(model.resultMessage)}
        .onAppear {model.visibleWindowCount += 1;model.configureSampling()}
        .onDisappear {model.visibleWindowCount=max(0,model.visibleWindowCount-1);model.configureSampling()}
        .onChange(of:model.selected) {_,_ in model.loadDetails()}
    }
    var subtitle:String {switch model.destination {
    case .overview:"A live view of your Mac, collected on this device."
    case .applications:"Application groups and their associated processes."
    case .processes:"Inspect resource use and manage individual processes."
    case .cpu:"Monotonic CPU deltas across all logical cores."
    case .memory:"Memory accounting and operating-system pressure."
    case .gpu:"Optional Apple Silicon measurements, with explicit availability."
    case .storage:"Mounted volumes and process I/O accounting."
    case .network:"Interface traffic, with tunnels and loopback kept visible."
    case .ports:"Find listeners and verify port release after termination."
    case .power:"Battery state and public thermal-pressure signals."
    case .history:"Bounded aggregate history with visible sampling gaps."
    case .diagnostics:"Provider provenance, permissions and capability status."
    }}
    @ViewBuilder var content:some View {switch model.destination {
    case .overview:OverviewView(model:model)
    case .applications:ApplicationsView(model:model)
    case .processes:ProcessView(model:model,context:.processes)
    case .cpu:CPUView(model:model)
    case .memory:MemoryView(model:model)
    case .gpu:ExperimentalView(model:model)
    case .storage:StorageView(model:model)
    case .network:NetworkView(model:model)
    case .ports:PortsView(model:model)
    case .power:PowerView(model:model)
    case .history:HistoryView(model:model)
    case .diagnostics:DiagnosticsView(model:model)
    }}
}
struct MetricCard:View {
    let title:String,value:String,detail:String,symbol:String
    var tint:Color = .accentColor
    var body:some View {
        VStack(alignment:.leading,spacing:14) {HStack {Text(title).font(.subheadline.weight(.medium)).foregroundStyle(.secondary);Spacer();Image(systemName:symbol).foregroundStyle(tint)};Text(value).font(.system(size:29,weight:.medium,design:.rounded)).monospacedDigit();Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(2)}.frame(maxWidth:.infinity,alignment:.leading).padding(18).background(.background,in:RoundedRectangle(cornerRadius:14)).overlay(RoundedRectangle(cornerRadius:14).stroke(.primary.opacity(0.07),lineWidth:1))
    }
}
struct ChartPanel:View {
    let title:String,points:[HistoryPoint]
    var percent=false
    private struct Plot:Identifiable {let id:Double,date:Date,value:Double,segment:Int}
    private var plot:[Plot] {
        var segment=0,last:Double?,result:[Plot]=[]
        for p in points {if let previous=last,p.monotonic-previous > 12 {segment += 1};last=p.monotonic;guard let value=p.value else {segment += 1;continue};result.append(Plot(id:p.monotonic,date:p.date,value:value,segment:segment))};return result
    }
    var body:some View {
        GroupBox {VStack(alignment:.leading,spacing:14) {
            HStack {Text(title).font(.headline);Spacer();Text("LIVE").font(.caption2.weight(.semibold)).tracking(1).foregroundStyle(.secondary)}
            if plot.isEmpty {ContentUnavailableView("Waiting for measurements",systemImage:"waveform.path",description:Text("Unavailable values are kept separate from zero.")).frame(height:155)}
            else {Chart(plot) {p in LineMark(x:.value("Time",p.date),y:.value("Value",p.value),series:.value("Segment",p.segment)).foregroundStyle(Color.accentColor).lineStyle(StrokeStyle(lineWidth:2))}.chartYScale(domain:percent ? 0...100:0...max(1,(plot.map(\.value).max() ?? 1)*1.1)).chartXAxis {AxisMarks(values:.automatic(desiredCount:4))}.chartYAxis {AxisMarks(position:.leading,values:.automatic(desiredCount:4))}.frame(height:160).accessibilityLabel(title)}
        }.padding(10)}
    }
}
struct OverviewView:View {
    @Bindable var model:AppModel
    var body:some View {
        ScrollView {VStack(alignment:.leading,spacing:20) {
            HStack(spacing:14) {MetricCard(title:"CPU",value:model.cpuText,detail:"\(model.snapshot?.cpuTicks.count ?? 0) logical cores · machine total",symbol:"cpu");MetricCard(title:"Accounted memory",value:Format.bytes(model.snapshot?.memory?.accounted),detail:"Active + wired + compressed",symbol:"memorychip",tint:.purple);MetricCard(title:"Memory pressure",value:model.update?.pressure == "Unknown (no notification received)" ? "Unknown":model.update?.pressure ?? "Unknown",detail:"macOS pressure notifications",symbol:"waveform.path",tint:.green)}
            ChartPanel(title:"CPU activity",points:model.histories["cpu.busy"]?.downsample(window:60,endingAt:model.snapshot?.monotonic ?? 0) ?? [],percent:true)
        }.padding(24)}
    }
}
struct CPUView:View {
    @Bindable var model:AppModel
    var body:some View {ScrollView {VStack(alignment:.leading,spacing:20) {
        HStack {MetricCard(title:"User",value:Format.percent(model.snapshot?.systemCPU?.user),detail:"Share of sampled ticks",symbol:"person");MetricCard(title:"System",value:Format.percent(model.snapshot?.systemCPU?.system),detail:"Share of sampled ticks",symbol:"gearshape");MetricCard(title:"Idle",value:Format.percent(model.snapshot?.systemCPU?.idle),detail:"Share of sampled ticks",symbol:"moon")}
        ChartPanel(title:"CPU activity",points:model.histories["cpu.busy"]?.points ?? [],percent:true)
        Text("Logical cores").font(.headline)
        LazyVGrid(columns:[GridItem(.adaptive(minimum:130))],spacing:12) {ForEach(Array((model.snapshot?.cpu ?? []).enumerated()),id:\.offset) {i,usage in VStack(alignment:.leading) {HStack {Text("Core \(i)");Spacer();Text(Format.percent(usage?.busy))};ProgressView(value:usage?.busy ?? 0,total:100)}.font(.caption).padding(12).background(.background,in:RoundedRectangle(cornerRadius:8))}}
        Text("Core indices are reported by Mach. Performance/efficiency labels are unavailable until their mapping is validated.").font(.caption).foregroundStyle(.secondary)
        LabeledContent("Load averages (1 / 5 / 15 min)",value:(model.snapshot?.load ?? []).map {String(format:"%.2f",$0)}.joined(separator:" / "))
    }.padding(24)}}
}
struct MemoryView:View {
    @Bindable var model:AppModel
    var body:some View {ScrollView {VStack(alignment:.leading,spacing:18) {
        HStack {MetricCard(title:"Physical memory",value:Format.bytes(model.snapshot?.memory?.total),detail:"Installed system memory",symbol:"memorychip");MetricCard(title:"Swap used",value:Format.bytes(model.snapshot?.memory?.swapUsed),detail:"Capacity \(Format.bytes(model.snapshot?.memory?.swapTotal))",symbol:"arrow.left.arrow.right")}
        GroupBox("Accounting components") {VStack(spacing:13) {LabeledContent("Active",value:Format.bytes(model.snapshot?.memory?.active));LabeledContent("Inactive",value:Format.bytes(model.snapshot?.memory?.inactive));LabeledContent("Wired",value:Format.bytes(model.snapshot?.memory?.wired));LabeledContent("Compressor physical storage",value:Format.bytes(model.snapshot?.memory?.compressed));LabeledContent("Free",value:Format.bytes(model.snapshot?.memory?.free));LabeledContent("Speculative",value:Format.bytes(model.snapshot?.memory?.speculative));LabeledContent("Purgeable (overlaps other categories)",value:Format.bytes(model.snapshot?.memory?.purgeable))}.padding(12)}
        LabeledContent("Memory pressure",value:model.update?.pressure ?? "Unknown")
        Text("Free pages are not all available memory. Purgeable and speculative values must not be added indiscriminately to other components. Pressure is an operating-system signal, not a percentage of RAM occupancy.").font(.caption).foregroundStyle(.secondary)
        ChartPanel(title:"Active + wired + compressed (bytes)",points:model.histories["memory.accounted"]?.points ?? [])
        GroupBox("Cumulative page activity") {VStack {LabeledContent("Pages read",value:model.snapshot?.memory.map {String($0.pageIns)} ?? "—");LabeledContent("Pages written",value:model.snapshot?.memory.map {String($0.pageOuts)} ?? "—");LabeledContent("Swap pages in / out",value:model.snapshot?.memory.map {"\($0.swapIns) / \($0.swapOuts)"} ?? "—")}.padding(10)}
    }.padding(24)}}
}
struct ApplicationsView:View {
    @Bindable var model:AppModel
    var body:some View {ScrollView {LazyVStack(alignment:.leading,spacing:16) {
        if model.groups.isEmpty {ContentUnavailableView("No application groups visible",systemImage:"app.dashed",description:Text("Processes without an observed application bundle remain in the process table."))}
        ForEach(model.groups) {group in GroupBox {VStack(alignment:.leading,spacing:12) {
            HStack {Image(systemName:"app.fill").font(.title2).foregroundStyle(.tint);VStack(alignment:.leading) {Text(group.name).font(.headline);Text("\(group.members.count) processes\(group.accountingIncomplete ? " · partial accounting":"")").font(.caption).foregroundStyle(.secondary)};Spacer();Text(Format.percent(group.cpuPercent)).monospacedDigit();Text(Format.bytes(group.footprintSum)).monospacedDigit()}
            ForEach(group.members,id:\.process.identity) {member in Button {model.selected=member.process.identity;model.destination = .processes} label:{HStack {Text(member.process.name);Text("\(member.process.identity.pid)").foregroundStyle(.secondary);Spacer();Text(member.membership == .exact ? "Bundle path":"Inferred ancestry").font(.caption).foregroundStyle(.secondary)}}.buttonStyle(.plain)}
        }.padding(10)}}
        Text("Bundle-path membership is exact for the observed executable path. Ancestry is inferred and can be incomplete; shared services remain unassigned. Footprints are process-accounting sums, not unique RAM.").font(.caption).foregroundStyle(.secondary)
    }.padding(24)}}
}
struct StorageView:View {
    @Bindable var model:AppModel
    var body:some View {ScrollView {VStack(alignment:.leading,spacing:18) {
        if model.snapshot?.volumes.isEmpty ?? true {ContentUnavailableView("No volumes visible",systemImage:"internaldrive",description:Text("Volume capacity is unavailable from Foundation in this session."))}
        ForEach(model.snapshot?.volumes ?? []) {volume in GroupBox {VStack(alignment:.leading,spacing:12) {Label(volume.name,systemImage:volume.internalVolume == false ? "externaldrive":"internaldrive").font(.headline);Text(volume.path).font(.caption).foregroundStyle(.secondary);if let total=volume.total,let available=volume.available,total > 0 {ProgressView(value:Double(total-available),total:Double(total));HStack {Text("\(Format.bytes(UInt64(max(0,total-available)))) occupied");Spacer();Text("\(Format.bytes(UInt64(max(0,available)))) available")}.font(.caption)} else {Text(volume.error ?? "Capacity unavailable").foregroundStyle(.secondary)}}.padding(10)}}
        Text("APFS volumes may share container capacity. Values are displayed per volume and are never summed into a misleading drive total.").font(.caption).foregroundStyle(.secondary)
        GroupBox("Process I/O") {Text("Rank processes below by combined activity, reads or writes. These are libproc accounting rates, not physical disk traffic.").padding(10)}
        if model.snapshot?.disks.isEmpty ?? true {UnavailableMetric(title:"Storage-driver traffic",message:"No IOBlockStorageDriver statistics are exposed in this session.",symbol:"internaldrive")}
        ForEach(model.snapshot?.disks ?? []) {disk in
            GroupBox(disk.name+" · "+String(disk.id)) {HStack {LabeledContent("Read",value:Format.rate(disk.readRate));Spacer();LabeledContent("Write",value:Format.rate(disk.writeRate))}.padding(10)}
        }
        Text("Documented storage-driver counters are separate from process accounting. Driver instances are not summed, and these values do not establish NAND-level traffic.").font(.caption).foregroundStyle(.secondary)
    }.padding(24)}}
}
struct NetworkView:View {
    @Bindable var model:AppModel
    var body:some View {ScrollView {VStack(alignment:.leading,spacing:18) {
        Text("Traffic is shown per interface. Physical, tunnel, virtual and loopback counters are not added together, since one packet can traverse several interfaces.").font(.callout).foregroundStyle(.secondary)
        ForEach(model.snapshot?.interfaces ?? []) {i in GroupBox {VStack(alignment:.leading,spacing:12) {HStack {Label(i.name,systemImage:i.kind == .tunnel ? "lock.shield":"network").font(.headline);Text(i.kind.rawValue.capitalized).foregroundStyle(.secondary);Spacer();Text(i.up ? "Up":"Down").font(.caption)};HStack {Label(Format.rate(i.receiveRate),systemImage:"arrow.down");Spacer();Label(Format.rate(i.sendRate),systemImage:"arrow.up")}.font(.title3).monospacedDigit();HStack {Text("Received \(Format.bytes(i.received))");Spacer();Text("Sent \(Format.bytes(i.sent))")}.font(.caption).foregroundStyle(.secondary)}.padding(10)}}
        UnavailableMetric(title:"Per-process network attribution",message:"No validated attribution provider is configured. Socket ownership does not establish traffic volume.",symbol:"app.connected.to.app.below.fill")
    }.padding(24)}}
}
struct PowerView:View {
    @Bindable var model:AppModel
    var body:some View {ScrollView {VStack(alignment:.leading,spacing:18) {
        HStack {MetricCard(title:"Thermal state",value:model.snapshot?.thermal ?? "Unknown",detail:"ProcessInfo thermal state",symbol:"thermometer.medium");MetricCard(title:"Battery",value:Format.percent(model.snapshot?.battery?.percentage),detail:model.snapshot?.battery.map {"\($0.source) · \($0.charging ? "Charging":"Not charging")"} ?? "Battery unavailable on this hardware",symbol:"battery.100percent")}
        UnavailableMetric(title:"Temperatures, fans and power",message:model.experimentalStatus+" Thermal state is not a temperature reading. Memoria does not control fans.",symbol:"fan")
        ForEach(model.experimentalSamples.values.filter {$0.id.contains("temperature") || $0.id.hasPrefix("fan.") || $0.id.hasSuffix(".power")}.sorted {$0.id<$1.id}) {sample in
            LabeledContent(sample.id,value:sample.value?.double.map {String(format:"%.2f",$0)+" "+sample.unit.rawValue} ?? sample.availability.rawValue)
        }
    }.padding(24)}}
}
struct ExperimentalView:View {
    @Bindable var model:AppModel
    var body:some View {ScrollView {VStack(alignment:.leading,spacing:20) {
        UnavailableMetric(title:"Experimental telemetry",message:model.experimentalStatus,symbol:"square.3.layers.3d")
        ForEach([("gpu.active","GPU active residency"),("gpu.scaled","GPU frequency-scaled activity"),("gpu.frequency","GPU frequency"),("gpu.power","GPU power"),("cpu.power","CPU power"),("dram.power","DRAM power"),("ane.power","ANE power")],id:\.0) {id,title in
            LabeledContent(title,value:model.experimentalSamples[id].flatMap {s in s.value?.double.map {String(format:"%.3f", $0)+" "+s.unit.rawValue}} ?? "Unavailable")
        }
        LabeledContent("Per-process GPU attribution",value:"Unavailable")
        Text("Active residency and frequency-scaled activity are different measurements. ANE power is not utilisation. Apple Silicon uses unified memory; no dedicated VRAM value is invented.").foregroundStyle(.secondary)
        Button("Provider diagnostics") {model.destination = .diagnostics}
    }.padding(24)}}
}
struct UnavailableMetric:View {
    let title:String,message:String,symbol:String
    var body:some View {GroupBox {HStack(alignment:.top,spacing:14) {Image(systemName:symbol).font(.title2).foregroundStyle(.secondary);VStack(alignment:.leading,spacing:8) {Text(title).font(.headline);Text(message).font(.callout).foregroundStyle(.secondary)};Spacer()}.padding(14)}}
}
struct HistoryView:View {
    @Bindable var model:AppModel
    var body:some View {ScrollView {VStack(alignment:.leading,spacing:20) {
        HStack {Picker("Time window",selection:$model.historyWindow) {ForEach(HistoryWindow.allCases) {Text($0.title).tag($0)}}.frame(width:240);Spacer();Menu("Export") {Button("JSON…") {model.exportHistory(csv:false)};Button("CSV…") {model.exportHistory(csv:true)}}}
        ChartPanel(title:"CPU (%)",points:model.histories["cpu.busy"]?.downsample(window:Double(model.historyWindow.rawValue),endingAt:model.snapshot?.monotonic ?? 0) ?? [],percent:true)
        ChartPanel(title:"Accounted memory (bytes)",points:model.histories["memory.accounted"]?.downsample(window:Double(model.historyWindow.rawValue),endingAt:model.snapshot?.monotonic ?? 0) ?? [])
        Text("Up to 3,601 points per metric, retained for one hour. Downsampling uses time buckets; missing samples and sleep boundaries remain gaps.").font(.caption).foregroundStyle(.secondary)
        LabeledContent("Persistent recording",value:model.recordingStatus)
        ForEach(Array(model.pinned).sorted {$0.pid<$1.pid},id:\.self) {identity in
            HStack {Text("Pinned PID \(identity.pid)");Spacer();Button("Unpin") {model.togglePin(identity)}}
            ChartPanel(title:"Process CPU (%)",points:model.processHistories[identity]?["cpu"]?.downsample(window:Double(model.historyWindow.rawValue),endingAt:model.snapshot?.monotonic ?? 0) ?? [])
        }
    }.padding(24)}}
}
struct DiagnosticsView:View {
    @Bindable var model:AppModel
    var body:some View {ScrollView {VStack(alignment:.leading,spacing:18) {
        ForEach(model.capabilities) {c in GroupBox {VStack(alignment:.leading,spacing:8) {HStack {Text(c.name).font(.headline);Spacer();Text("Tier \(c.tier.rawValue) · \(c.availability.rawValue)").font(.caption).foregroundStyle(.secondary)};Text(c.explanation).foregroundStyle(.secondary)}.padding(10)}}
        ForEach(model.snapshot?.errors ?? [],id:\.self) {Text($0).foregroundStyle(.orange)}
        Text("Inaccessible or exited processes in latest enumeration: \(model.snapshot?.skippedProcesses ?? 0)").font(.caption)
        Text("Permission denial alone does not establish SIP protection. Apple signing and root ownership do not prove protection.").font(.caption).foregroundStyle(.secondary)
        ForEach((model.update?.metrics ?? [])+model.experimentalSamples.values.sorted {$0.id<$1.id}) {m in DisclosureGroup(m.id) {VStack(alignment:.leading) {Text("\(m.provider) · \(m.api) · \(m.measurement.rawValue)");Text("\(m.availability.rawValue) · \(m.unit.rawValue) · interval \(m.interval.formatted()) seconds");Text("Permission: "+m.permission.rawValue);if let error=m.error {Text(error)};Text(m.quality)}.font(.caption).frame(maxWidth:.infinity,alignment:.leading)}}
    }.padding(24)}}
}
