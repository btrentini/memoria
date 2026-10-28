import SwiftUI
import Charts
import MemoriaCore
import MemoriaCollectors

/// A single scrolling summary keeps charts and a bounded process list together.
struct SimpleDashboardView:View {
    @Bindable var model:AppModel
    let context:ProcessListContext
    private let columns=[GridItem(.adaptive(minimum:300),spacing:16)]
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:18) {
                if context == .memory {
                    MemoryUsageSummary(used:model.snapshot?.memory?.accounted,total:model.snapshot?.memory?.total)
                } else {
                    LazyVGrid(columns:columns,spacing:16) {
                        MetricCard(title:"CPU",value:model.cpuText,detail:"Whole machine",symbol:"cpu")
                        MetricCard(title:"Accounted memory",value:Format.bytes(context == .applications ? model.applicationMemory.systemAccounted:model.snapshot?.memory?.accounted),detail:"Active + wired + compressed",symbol:"memorychip",tint:.purple)
                    }
                }
                if context == .applications {ApplicationMemoryCaption(date:model.applicationMemory.date)}
                SimpleCharts(model:model,context:context)
                SimpleTopProcesses(model:model,context:context)
            }.padding(20)
        }.accessibilityIdentifier("simple-dashboard-"+context.rawValue)
    }
}

private struct SimpleCharts:View {
    @Bindable var model:AppModel
    let context:ProcessListContext
    private let columns=[GridItem(.adaptive(minimum:300),spacing:16)]
    private var window:Double {context == .history ? Double(model.historyWindow.rawValue):60}
    private func points(_ id:String,scale:Double=1) -> [HistoryPoint] {
        (model.histories[id]?.downsample(window:window,endingAt:(context == .applications && id == "memory.accounted" ? model.applicationMemory.monotonic:model.snapshot?.monotonic) ?? 0) ?? [])
            .map {HistoryPoint(date:$0.date,monotonic:$0.monotonic,value:$0.value.map {$0/scale})}
    }
    var body:some View {
        VStack(alignment:.leading,spacing:12) {
            if context == .history {
                Picker("Time window",selection:$model.historyWindow) {
                    ForEach(HistoryWindow.allCases) {Text($0.title).tag($0)}
                }.frame(width:250)
            }
            charts
        }
    }
    @ViewBuilder private var charts:some View {
        switch context {
        case .cpu:
            ChartPanel(title:"CPU activity · last 60 seconds",points:points("cpu.busy"),percent:true)
        case .memory:
            LazyVGrid(columns:columns,spacing:16) {
                ChartPanel(title:"Accounted memory (GiB)",points:points("memory.accounted",scale:1_073_741_824))
                ChartPanel(title:"Swap used (GiB)",points:points("memory.swap",scale:1_073_741_824))
            }
        case .network:
            SimpleNetworkCharts(model:model)
        case .storage:
            SimpleStorageCharts(model:model)
        case .gpu:
            SimpleBars(title:"GPU active residency",unit:"%",values:[("GPU",sample("gpu.active"))],ceiling:100)
            Text(model.experimentalStatus).font(.caption).foregroundStyle(.secondary)
        case .power:
            HStack {
                LabeledContent("Battery",value:Format.percent(model.snapshot?.battery?.percentage))
                Spacer()
                LabeledContent("Thermal state",value:model.snapshot?.thermal ?? "Unknown")
            }
            SimpleBars(title:"Experimental power readings",unit:"W",values:[("CPU",sample("cpu.power")),("GPU",sample("gpu.power")),("DRAM",sample("dram.power")),("ANE",sample("ane.power"))])
            Text(model.experimentalStatus).font(.caption).foregroundStyle(.secondary)
        case .ports:
            if let scan=model.scan {
                SimpleBars(title:"Visible endpoints · latest scan",unit:"count",values:[
                    ("TCP listeners",Double(scan.endpoints.filter {$0.transport == .tcp && $0.isListener}.count)),
                    ("UDP unconnected",Double(scan.endpoints.filter {$0.transport == .udp && $0.isListener}.count)),
                    ("TCP established",Double(scan.endpoints.filter {$0.transport == .tcp && $0.state == "ESTABLISHED"}.count))
                ])
                Text(scan.coverage).font(.caption).foregroundStyle(.secondary)
            } else {
                UnavailableMetric(title:"Socket summary",message:"Refresh sockets to count visible endpoints.",symbol:"network")
            }
            Button(model.scanning ? "Refreshing…":"Refresh sockets") {model.refreshPorts()}.disabled(model.scanning)
        case .diagnostics:
            if model.capabilities.isEmpty {
                UnavailableMetric(title:"Provider status",message:"Waiting for capability discovery.",symbol:"checkmark.shield")
            } else {
                SimpleBars(title:"Provider capability status",unit:"count",values:providerCounts)
            }
        default:
            LazyVGrid(columns:columns,spacing:16) {
                ChartPanel(title:"System CPU (%)",points:points("cpu.busy"),percent:true)
                ChartPanel(title:"System accounted memory (GiB)",points:points("memory.accounted",scale:1_073_741_824))
            }
        }
    }
    private func sample(_ id:String) -> Double? {model.experimentalSamples[id]?.value?.double}
    private var providerCounts:[(String,Double?)] {
        Dictionary(grouping:model.capabilities,by:{$0.availability.rawValue}).sorted {$0.key<$1.key}
            .map {($0.key,Double($0.value.count))}
    }
}

private struct SimpleBars:View {
    let title:String,unit:String
    let values:[(String,Double?)]
    var ceiling:Double?
    private struct Value:Identifiable {let id:String,value:Double}
    private var measured:[Value] {
        values.compactMap {name,value in
            guard let value,value.isFinite,value>=0 else {return nil}
            return Value(id:name,value:value)
        }
    }
    var body:some View {
        GroupBox {
            VStack(alignment:.leading,spacing:10) {
                Text(title).font(.headline)
                if measured.isEmpty {
                    ContentUnavailableView("Measurements unavailable",systemImage:"chart.bar",description:Text("No measured values are available for this chart.")).frame(height:150)
                } else {
                    Chart(measured) {value in
                        BarMark(x:.value(unit,value.value),y:.value("Category",value.id))
                            .foregroundStyle(Color.accentColor)
                            .annotation(position:.trailing) {Text(value.value.formatted(.number.precision(.fractionLength(0...1)))+" "+unit).font(.caption).monospacedDigit()}
                    }.chartXScale(domain:0...(ceiling ?? max(1,(measured.map(\.value).max() ?? 1)*1.2)))
                        .frame(height:max(90,Double(measured.count)*36))
                        .accessibilityLabel(title)
                }
                if measured.count<values.count {
                    Text("Unavailable: "+values.filter {$0.1 == nil || $0.1?.isFinite == false || ($0.1 ?? 0)<0}.map(\.0).joined(separator:", ")).font(.caption).foregroundStyle(.secondary)
                }
            }.padding(10)
        }
    }
}

private struct SimpleNetworkCharts:View {
    @Bindable var model:AppModel
    @State private var selected=""
    private var interfaces:[InterfaceSnapshot] {model.snapshot?.interfaces ?? []}
    private var interface:InterfaceSnapshot? {
        interfaces.first {$0.id == selected} ?? interfaces.first {$0.kind == .physical && $0.up} ?? interfaces.first {$0.up} ?? interfaces.first
    }
    private func points(_ direction:String,_ name:String) -> [HistoryPoint] {
        (model.histories["network.\(name).\(direction)"]?.downsample(window:60,endingAt:model.snapshot?.monotonic ?? 0) ?? [])
            .map {HistoryPoint(date:$0.date,monotonic:$0.monotonic,value:$0.value.map {$0/1_048_576})}
    }
    var body:some View {
        VStack(alignment:.leading,spacing:12) {
            if let interface {
                Picker("Interface",selection:Binding(get:{self.interface?.id ?? ""},set:{selected=$0})) {
                    ForEach(interfaces) {Text($0.name+" · "+$0.kind.rawValue).tag($0.id)}
                }.frame(maxWidth:350)
                LazyVGrid(columns:[GridItem(.adaptive(minimum:300))],spacing:16) {
                    ChartPanel(title:"\(interface.name) received (MiB/s)",points:points("receive",interface.name))
                    ChartPanel(title:"\(interface.name) sent (MiB/s)",points:points("send",interface.name))
                }
                Text("One interface at a time; physical and tunnel traffic can overlap.").font(.caption).foregroundStyle(.secondary)
            } else {
                UnavailableMetric(title:"Network charts",message:"No interfaces are currently visible.",symbol:"network")
            }
        }
    }
}

private struct SimpleStorageCharts:View {
    @Bindable var model:AppModel
    @State private var selected:UInt64=0
    private var disks:[DiskSnapshot] {model.snapshot?.disks ?? []}
    private var disk:DiskSnapshot? {disks.first {$0.id == selected} ?? disks.first}
    private func points(_ direction:String,_ id:UInt64) -> [HistoryPoint] {
        (model.histories["disk.\(id).\(direction)"]?.downsample(window:60,endingAt:model.snapshot?.monotonic ?? 0) ?? [])
            .map {HistoryPoint(date:$0.date,monotonic:$0.monotonic,value:$0.value.map {$0/1_048_576})}
    }
    var body:some View {
        VStack(alignment:.leading,spacing:12) {
            if let disk {
                Picker("Storage driver",selection:Binding(get:{self.disk?.id ?? 0},set:{selected=$0})) {
                    ForEach(disks) {Text($0.name+" · "+String($0.id)).tag($0.id)}
                }.frame(maxWidth:400)
                LazyVGrid(columns:[GridItem(.adaptive(minimum:300))],spacing:16) {
                    ChartPanel(title:"Driver reads (MiB/s)",points:points("read",disk.id))
                    ChartPanel(title:"Driver writes (MiB/s)",points:points("write",disk.id))
                }
                Text("One storage driver at a time. Driver counters and process accounting measure different activity.").font(.caption).foregroundStyle(.secondary)
            } else {
                UnavailableMetric(title:"Storage charts",message:"Storage-driver activity is unavailable in this session.",symbol:"internaldrive")
            }
        }
    }
}

private struct SimpleRankingRefresh:Hashable {
    let context:ProcessListContext
    let metric:ProcessSort
    let sampledAt:Double?
}
private struct SimpleTopProcesses:View {
    @Bindable var model:AppModel
    let context:ProcessListContext
    @State private var ranking:TopProcesses?
    @State private var error:String?
    private var metric:ProcessSort {model.simpleProcessMetrics[context] ?? context.defaultSort}
    private var refresh:SimpleRankingRefresh {SimpleRankingRefresh(context:context,metric:metric,sampledAt:context == .applications ? model.applicationSampleTime:model.snapshot?.monotonic)}
    var body:some View {
        GroupBox {
            VStack(alignment:.leading,spacing:10) {
                HStack {
                    Text("Top 10 processes").font(.headline)
                    Spacer()
                    Picker("Rank by",selection:Binding(get:{metric},set:{model.setSimpleProcessMetric($0,for:context)})) {
                        ForEach(ProcessSort.allCases.filter(\.isResource),id:\.self) {Text($0.title).tag($0)}
                    }.frame(width:230)
                }
                if model.sleeping || model.snapshot == nil {
                    Text(model.sleeping ? "Monitoring paused":"Waiting for processes…").foregroundStyle(.secondary)
                } else if let ranking,ranking.metric == metric {
                    if ranking.processes.isEmpty {Text("No measured process values available.").foregroundStyle(.secondary)}
                    let maximum=max(1,ranking.processes.compactMap {ranking.metric.value(in:$0)}.max() ?? 1)
                    ForEach(Array(ranking.processes.enumerated()),id:\.element.identity) {index,process in
                        Button {model.inspectFromSummary(process.identity)} label:{
                            HStack(spacing:10) {
                                Text(String(index+1)).monospacedDigit().foregroundStyle(.secondary).frame(width:24,alignment:.trailing)
                                Text(process.name).lineLimit(1).frame(maxWidth:.infinity,alignment:.leading)
                                Text("PID \(process.identity.pid)").font(.caption).foregroundStyle(.secondary)
                                ProgressView(value:ranking.metric.value(in:process) ?? 0,total:maximum).frame(width:110).accessibilityHidden(true)
                                Text(value(process,ranking.metric)).monospacedDigit().frame(width:110,alignment:.trailing)
                                Image(systemName:"chevron.right").font(.caption).foregroundStyle(.secondary)
                            }.padding(.vertical,5).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                            .accessibilityIdentifier("simple-process-row-\(process.identity.pid)")
                            .help("Open Full view and inspect this process")
                        if index<ranking.processes.count-1 {Divider()}
                    }
                    Text("\(ranking.processes.count) shown · \(ranking.measuredCount) measured · \(ranking.unavailableCount) unavailable\(context == .applications ? " · application-associated processes":" · all visible processes")")
                        .font(.caption).foregroundStyle(.secondary)
                } else if let error {Text(error).foregroundStyle(.secondary)}
                else {ProgressView().controlSize(.small)}
                HStack(alignment:.top) {
                    Text(context.note+" Bars are relative to the largest displayed value.").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Full view") {model.simplifiedView=false}
                }
            }.padding(10)
        }.accessibilityElement(children:.contain).accessibilityIdentifier("simple-top-processes-"+context.rawValue)
            .task(id:refresh) {await updateRanking()}
    }
    private func value(_ process:ProcessSnapshot,_ metric:ProcessSort) -> String {
        switch metric {
        case .cpu:Format.percent(metric.value(in:process))
        case .memory:Format.bytes(process.footprintBytes)
        case .resident:Format.bytes(process.residentBytes)
        case .threads:process.threads.map(String.init) ?? "—"
        case .io,.read,.write:Format.rate(metric.value(in:process))
        default:"—"
        }
    }
    private func updateRanking() async {
        guard model.snapshot != nil else {ranking=nil;error=nil;return}
        let input=model.displayedProcesses(for:context),context=self.context,metric=self.metric,uid=getuid()
        do {
            let result=try await model.executor.run {TopProcesses.rank(input,context:context,metric:metric,currentUID:uid)}
            guard !Task.isCancelled else {return}
            ranking=result;error=nil
        } catch {
            guard !Task.isCancelled else {return}
            ranking=nil;self.error=String(describing:error)
        }
    }
}
