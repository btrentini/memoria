import SwiftUI
import AppKit
import Observation
import UserNotifications
import MemoriaCore
import MemoriaCollectors
import MemoriaServices
import MemoriaWidgetSupport

enum Destination:String,CaseIterable,Identifiable {
    case overview="Overview",applications="Applications",processes="Processes",cpu="CPU",memory="Memory",gpu="GPU & Neural Engine",storage="Storage",network="Network",ports="Ports",power="Power & Thermals",history="History",diagnostics="Diagnostics"
    var id:String {rawValue}
    var processContext:ProcessListContext {
        switch self {
        case .overview:.overview;case .applications:.applications;case .processes:.processes;case .cpu:.cpu
        case .memory:.memory;case .gpu:.gpu;case .storage:.storage;case .network:.network;case .ports:.ports
        case .power:.power;case .history:.history;case .diagnostics:.diagnostics
        }
    }
    var symbol:String {switch self {case .overview:"square.grid.2x2";case .applications:"app.dashed";case .processes:"list.bullet.rectangle";case .cpu:"cpu";case .memory:"memorychip";case .gpu:"square.3.layers.3d";case .storage:"internaldrive";case .network:"network";case .ports:"point.3.connected.trianglepath.dotted";case .power:"bolt.heart";case .history:"clock.arrow.circlepath";case .diagnostics:"checkmark.shield"}}
}
struct ActionReview:Identifiable {
    let id=UUID()
    let targets:[TerminationTarget]
    let action:TerminationAction
    let query:PortQuery?
    let endpoints:[EndpointRecord]
    let treeRoot:ProcessIdentity?
    var administrator=false
    var parents:[ProcessIdentity:Int32]=[:]
}
@MainActor @Observable final class AppModel {
    let telemetry=TelemetryCoordinator(),ports=PortCollector(),actions=ProcessActionCoordinator()
    let experimental=ExperimentalProvider()
    let executor=NativeExecutor()
    let details=ProcessDetailStore()
    var update:TelemetryUpdate?
    var capabilities:[Capability]=[]
    var destination:Destination = Destination(rawValue:UserDefaults.standard.string(forKey:"destination") ?? "") ?? .overview {
        didSet {UserDefaults.standard.set(destination.rawValue,forKey:"destination");configureExperimental()}
    }
    var processListPreferences: [ProcessListContext:ProcessListPreferences] = Dictionary(uniqueKeysWithValues:ProcessListContext.allCases.map { context in
        let saved=UserDefaults.standard.data(forKey:"processRanking."+context.rawValue)
            .flatMap {try? JSONDecoder().decode(ProcessListPreferences.self,from:$0)}
        return (context,saved ?? ProcessListPreferences(context:context))
    })
    var simplifiedView=UserDefaults.standard.bool(forKey:"simplifiedView") {
        didSet {UserDefaults.standard.set(simplifiedView,forKey:"simplifiedView")}
    }
    var simpleProcessMetrics:[ProcessListContext:ProcessSort] = Dictionary(uniqueKeysWithValues:ProcessListContext.allCases.map { context in
        let saved=UserDefaults.standard.string(forKey:"simpleProcessMetric."+context.rawValue).flatMap(ProcessSort.init(rawValue:))
        return (context,saved?.isResource == true ? saved! : context.defaultSort)
    })
    var menuBarVisible=UserDefaults.standard.object(forKey:"menuBarVisible") as? Bool ?? true {
        didSet {UserDefaults.standard.set(menuBarVisible,forKey:"menuBarVisible")}
    }
    var menuBarReading=UserDefaults.standard.string(forKey:"menuBarReading") ?? MenuBarReading.both.rawValue {
        didSet {UserDefaults.standard.set(menuBarReading,forKey:"menuBarReading")}
    }
    var widgetSharing=UserDefaults.standard.object(forKey:"widgetSharing") as? Bool ?? true {
        didSet {UserDefaults.standard.set(widgetSharing,forKey:"widgetSharing");publishWidget(force:true)}
    }
    var widgetStatus="Desktop widgets require a signed App Group."
    var showWidgetHelp=false
    var menuPopoverVisible=false
    @ObservationIgnored private let widgetPublisher=WidgetPublisher()
    var selected:ProcessIdentity?
    var groups:[ApplicationGroup]=[]
    var histories:[String:BoundedHistory]=[:]
    var processHistories:[ProcessIdentity:[String:BoundedHistory]]=[:]
    var pinned:Set<ProcessIdentity>=[]
    @ObservationIgnored private var processHistoryTimes:[ProcessIdentity:Double]=[:]
    var historyWindow:HistoryWindow = .minute
    var scan:PortScan?
    var portInput="8080"
    var listenersOnly=true
    var scanning=false
    var review:ActionReview?
    var reviewPresenter="main"
    var operationRunning=false
    var resultMessage=""
    var inspectorVisible=UserDefaults.standard.object(forKey:"inspectorVisible") as? Bool ?? true {
        didSet {UserDefaults.standard.set(inspectorVisible,forKey:"inspectorVisible")}
    }
    var commandPalette=false
    var sleeping=false
    var detailText=""
    var detailLoading=false
    var lastProcessSelection:ProcessIdentity?
    var shortcutStatus="Disabled"
    var experimentalStatus="Disabled. The optional worker is not enabled."
    var experimentalSamples:[String:MetricSample]=[:]
    var notificationStatus="Disabled"
    var recordingStatus="Off"
    var visibleWindowCount=0
    @ObservationIgnored private var operationTask:Task<Void,Never>?
    @ObservationIgnored private var monitorTask:Task<Void,Never>?
    @ObservationIgnored private var detailTask:Task<Void,Never>?
    @ObservationIgnored private var observers:[NSObjectProtocol]=[]
    @ObservationIgnored private var quickWindow:NSWindow?
    @ObservationIgnored private var hotKey:GlobalShortcut?
    @ObservationIgnored private var memoryAlert=AlertPolicy(high:0.9,reset:0.85)
    @ObservationIgnored private var pressureAlert=AlertPolicy(high:1,reset:0,requiredSamples:2)
    @ObservationIgnored private var recordTask:Task<Void,Never>?
    @ObservationIgnored private var workerTask:Task<Void,Never>?
    @ObservationIgnored private var experimentalRequested=false
    @ObservationIgnored private lazy var recording=RecordingStore(directory:FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("Memoria/Recordings",isDirectory:true))
    var snapshot:NativeSnapshot? {update?.snapshot}
    var selectedProcess:ProcessSnapshot? {snapshot?.processes.first {$0.identity == selected}}
    var cpuText:String {sleeping ? "Paused":Format.percent(snapshot?.systemCPU?.busy)}
    func start() {
        guard monitorTask == nil else {return}
        configureShortcut()
        configureExperimental()
        for (name,value) in [(NSWorkspace.willSleepNotification,true),(NSWorkspace.didWakeNotification,false)] {
            observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName:name,object:nil,queue:.main) {[weak self] _ in Task {@MainActor in
                guard let self else {return};self.sleeping=value
                let now=ProcessInfo.processInfo.systemUptime
                for key in self.histories.keys {self.histories[key]?.append(HistoryPoint(date:.now,monotonic:now,value:nil))}
                if value {self.update=nil;self.scan=nil;self.review=nil;self.operationTask?.cancel();self.publishWidget(force:true)}
                await self.telemetry.setSleeping(value)
                if value {self.experimentalRequested=false;self.workerTask?.cancel();await self.experimental.stop();self.experimentalStatus="Paused for sleep";self.experimentalSamples=[:]}
                else {self.configureExperimental()}
            }})
        }
        for name in [NSWindow.didMiniaturizeNotification,NSWindow.didDeminiaturizeNotification,NSWindow.didBecomeKeyNotification,NSWindow.willCloseNotification] {
            observers.append(NotificationCenter.default.addObserver(forName:name,object:nil,queue:.main) {[weak self] _ in Task {@MainActor in self?.configureSampling()}})
        }
        monitorTask=Task {[weak self] in
            guard let self else {return};self.capabilities=await telemetry.capabilities()
            for await next in await telemetry.updates() {
                if Task.isCancelled {break}
                self.update=next
                for metric in next.metrics {
                    if self.histories[metric.id] == nil {self.histories[metric.id]=BoundedHistory()}
                    self.histories[metric.id]?.append(HistoryPoint(date:metric.wallTime,monotonic:metric.monotonicTime,value:metric.value?.double))
                }
                // Interface churn cannot grow the history dictionary indefinitely.
                if self.histories.count > 128 {let live=Set(next.metrics.map(\.id));self.histories=self.histories.filter {live.contains($0.key)}}
                self.groups=(try? await self.executor.run {ApplicationGrouping.group(next.snapshot.processes)}) ?? []
                self.recordProcessHistory(next.snapshot)
                self.handleAlerts(next);self.record(next.metrics);self.publishWidget()
            }
        }
    }
    func configureSampling() {
        let visible=NSApp.windows.contains {$0.isVisible && !$0.isMiniaturized && ["Memoria","Quick Task Manager"].contains($0.title)}
        let requested=UserDefaults.standard.double(forKey:"samplingInterval")
        Task {await telemetry.configure(visible:visible || menuPopoverVisible,interval:requested > 0 ? requested:1)}
        configureExperimental()
    }
    func setProcessListPreferences(_ preferences:ProcessListPreferences,for context:ProcessListContext) {
        let previous=processListPreferences[context]
        processListPreferences[context]=preferences
        if previous?.persisted != preferences.persisted,let data=try? JSONEncoder().encode(preferences.persisted) {
            UserDefaults.standard.set(data,forKey:"processRanking."+context.rawValue)
        }
    }
    func setSimpleProcessMetric(_ metric:ProcessSort,for context:ProcessListContext) {
        guard metric.isResource else {return}
        simpleProcessMetrics[context]=metric
        UserDefaults.standard.set(metric.rawValue,forKey:"simpleProcessMetric."+context.rawValue)
    }
    func inspectFromSummary(_ identity:ProcessIdentity) {
        selected=identity;simplifiedView=false;inspectorVisible=true
    }
    func publishWidget(force:Bool=false) {
        guard sleeping || snapshot != nil || !widgetSharing else {return}
        let now=ProcessInfo.processInfo.systemUptime
        let date=snapshot?.date ?? Date.now
        let pressure=SummaryPressure(rawValue:(update?.pressure ?? "").lowercased()) ?? .unknown
        let used=snapshot?.memory?.accounted,total=snapshot?.memory?.total
        let validUsed:UInt64? = used.flatMap {value in total.map {value <= $0} == true ? value:nil}
        let history=(histories["cpu.busy"]?.downsample(window:60,endingAt:snapshot?.monotonic ?? 0,buckets:30) ?? [])
            .filter {$0.date<=date && $0.date>=date.addingTimeInterval(-120)}
            .suffix(30).map {SummaryPoint(date:$0.date,cpu:$0.value)}
        let summary=WidgetSummary(capturedAt:date,state:sleeping ? .paused:.captured,cpuPercent:sleeping ? nil:snapshot?.systemCPU?.busy,
            accountedMemory:sleeping ? nil:validUsed,totalMemory:sleeping ? nil:total,pressure:pressure,history:sleeping ? []:history)
        let enabled=widgetSharing
        Task {widgetStatus=await widgetPublisher.publish(summary,enabled:enabled,now:now,force:force)}
    }
    func handleWidgetURL(_ url:URL) {
        guard let route=WidgetRoute(url:url) else {return}
        switch route {
        case .overview:destination = .overview
        case .cpu:destination = .cpu
        case .memory:destination = .memory
        case .quick:showQuick();return
        }
        NSApp.activate()
    }
    func refreshPorts(fallback:Bool=false) {
        guard !scanning else {return};scanning=true
        Task {
            defer {scanning=false}
            if fallback {do {scan=try await LsofFallback().scan()} catch {resultMessage="lsof scan failed: \(error)"}}
            else {scan=await ports.scan(force:true)}
        }
    }
    func prepare(_ action:TerminationAction,tree:Bool=false) {
        reviewPresenter=NSApp.keyWindow?.title == "Quick Task Manager" ? "quick":"main"
        guard let process=selectedProcess else {return}
        let members=tree ? ProcessTree.descendants(of:process.identity,in:snapshot?.processes ?? [])+[process]:[process]
        let targets=members.compactMap(TerminationTarget.init)
        guard !targets.isEmpty else {resultMessage="Start time, boot session and executable identity are required before signalling.";return}
        var item=ActionReview(targets:targets,action:action,query:nil,endpoints:[],treeRoot:tree ? process.identity:nil)
        item.parents=Dictionary(members.map {($0.identity,$0.parentPID)},uniquingKeysWith:{a,_ in a})
        review=item
    }
    func prepareFreePort(_ endpoint:EndpointRecord,action:TerminationAction = .terminate) {
        reviewPresenter="main"
        guard let process=snapshot?.processes.first(where:{$0.identity == endpoint.process}),let target=TerminationTarget(process:process),let query=try? PortQuery("\(endpoint.localPort)/\(endpoint.transport.rawValue)") else {resultMessage="Refresh process and port snapshots before selecting this listener.";return}
        review=ActionReview(targets:[target],action:action,query:query,endpoints:[endpoint],treeRoot:nil)
    }
    func prepareAdministrator(_ action:TerminationAction) {
        reviewPresenter=NSApp.keyWindow?.title == "Quick Task Manager" ? "quick":"main"
        guard let target=selectedProcess.flatMap(TerminationTarget.init) else {return}
        review=ActionReview(targets:[target],action:action,query:nil,endpoints:[],treeRoot:nil,administrator:true)
    }
    func perform(_ review:ActionReview, selected:Set<ProcessIdentity>) {
        self.review=nil;operationRunning=true
        let request=TerminationRequest(targets:review.targets.filter {selected.contains($0.identity)},action:review.action,confirmed:true)
        operationTask=Task {
            defer{operationRunning=false;operationTask=nil}
            var results:[TerminationResult]
            if review.administrator {
                do {
                    let reply=try await AdministratorClient.perform(request)
                    results=reply.results;resultMessage=reply.error.map {$0+"\n"} ?? ""
                } catch {results=[];resultMessage="Administrator operation failed: \(error)\n"}
            } else if let query=review.query {
                let result=await FreePortCoordinator(ports:ports,actions:actions).perform(query:query,selected:review.endpoints,request:request)
                scan=result.scan;results=result.results
                resultMessage="\(result.remaining.isEmpty ? "No matching listener visible after rescan.":"\(result.remaining.count) matching listener(s) remain.") \(result.replacements.count) replacement listener(s). \(result.scan.coverage)\n"
            } else {results=await actions.perform(request);resultMessage=""}
            resultMessage += results.map {"\($0.target.name) (\($0.target.identity.pid)): \($0.message)"}.joined(separator:"\n")
            if let root=review.treeRoot {
                let reader=NativeReader()
                if let live=try? await executor.run({try reader.pids().compactMap {try? reader.process($0)}}) {
                    let survivors=ProcessTree.descendants(of:root,in:live)
                    let identities=Set(review.targets.map(\.identity))
                    let reviewedSurvivors=live.filter {identities.contains($0.identity)}
                    let reparented=reviewedSurvivors.filter {review.parents[$0.identity] != $0.parentPID}
                    let added=survivors.filter {!identities.contains($0.identity)}
                    resultMessage += "\n\(reviewedSurvivors.count) reviewed processes remain visible; \(reparented.count) changed parent; \(added.count) new attached descendants. These require a fresh review. New descendants that already reparented cannot be reconstructed from polling."
                    for process in reviewedSurvivors+added {resultMessage += "\nSurvivor: \(process.name) · PID \(process.identity.pid) · parent \(process.parentPID)"}
                }
            }
        }
    }
    func cancelOperation() {operationTask?.cancel()}
    func quitSelected() {
        reviewPresenter=NSApp.keyWindow?.title == "Quick Task Manager" ? "quick":"main"
        guard let target=selectedProcess.flatMap(TerminationTarget.init) else {return}
        operationRunning=true
        Task {let result=await actions.quitApplication(target);resultMessage=result.message;operationRunning=false}
    }
    func loadDetails(includeArguments:Bool=false) {
        detailTask?.cancel();detailText="";guard let process=selectedProcess else {return}
        detailLoading=true
        detailTask=Task {
            let metadata=try? await details.inspect(process)
            let text=try? await executor.run {
                let reader=NativeReader();let live=try reader.process(process.identity.pid)
                guard live.identity == process.identity,live.executable == process.executable else {throw InspectionError.identityChanged}
                var lines=["Identity: PID \(live.identity.pid), start \(live.identity.startSeconds).\(live.identity.startMicroseconds)","Executable: \(live.executable?.path ?? "Unavailable")"]
                if let metadata {lines += [metadata.signing,metadata.fileCoverage]+metadata.files}
                if includeArguments {lines.append("Arguments (may contain sensitive data):");lines += try reader.arguments(for:live)}
                return lines.joined(separator:"\n")
            }
            guard !Task.isCancelled,selected == process.identity else {return}
            detailText=text ?? "Details unavailable or process changed.";detailLoading=false
        }
    }
    func togglePin(_ identity:ProcessIdentity) {
        if pinned.contains(identity) {pinned.remove(identity)}
        else if pinned.count<8 {pinned.insert(identity)}
        else {resultMessage="Up to eight processes can be pinned."}
    }
    private func recordProcessHistory(_ snapshot:NativeSnapshot) {
        var keep=pinned;if let selected {keep.insert(selected)}
        processHistories=processHistories.filter {keep.contains($0.key)}
        processHistoryTimes=processHistoryTimes.filter {keep.contains($0.key)}
        for identity in keep {
            let process=snapshot.processes.first {$0.identity == identity}
            if let process,processHistoryTimes[identity] == process.observedAt {continue}
            var series=processHistories[identity] ?? [:]
            for (key,value) in [("cpu",process?.cpuPercent),("memory",process?.footprintBytes.map(Double.init))] {
                var history=series[key] ?? BoundedHistory()
                history.append(HistoryPoint(date:snapshot.date,monotonic:snapshot.monotonic,value:value))
                series[key]=history
            }
            processHistoryTimes[identity]=process?.observedAt
            processHistories[identity]=series
        }
    }
    func exportHistory(csv:Bool) {
        let panel=NSSavePanel();panel.nameFieldStringValue=csv ? "Memoria-history.csv":"Memoria-history.json"
        panel.message="Exports aggregate history only. Process names, paths and arguments are excluded."
        guard panel.runModal() == .OK,let url=panel.url else {return}
        let points=histories.mapValues(\.points)
        Task {do {try await executor.run {
            let data=csv ? Data(HistoryExport.csv(points).utf8):try JSONEncoder().encode(points)
            try data.write(to:url,options:.atomic)
        };resultMessage="History exported to \(url.lastPathComponent)."} catch {resultMessage="Export failed: \(error)"}}
    }
    func showQuick() {
        if quickWindow == nil {
            let controller=NSHostingController(rootView:QuickView(model:self))
            let window=NSWindow(contentViewController:controller);window.title="Quick Task Manager";window.setContentSize(NSSize(width:900,height:530));window.styleMask=[.titled,.closable,.resizable,.miniaturizable];window.isReleasedWhenClosed=false;window.setFrameAutosaveName("MemoriaQuick");quickWindow=window
        }
        NSApp.activate();quickWindow?.makeKeyAndOrderFront(nil)
    }
    func configureShortcut() {
        hotKey?.unregister();hotKey=nil
        guard UserDefaults.standard.object(forKey:"shortcutEnabled") as? Bool ?? true else {shortcutStatus="Disabled";return}
        let key=UserDefaults.standard.string(forKey:"shortcutKey") ?? "Escape"
        let shortcut=GlobalShortcut();hotKey=shortcut
        shortcutStatus=shortcut.register(key:key) {[weak self] in self?.showQuick()}
    }
    func configureExperimental() {
        let enabled=UserDefaults.standard.bool(forKey:"experimentalEnabled")
        let visible=NSApp.windows.contains {$0.isVisible && !$0.isMiniaturized && $0.title == "Memoria"}
        let wanted=enabled && !sleeping && visible && [.gpu,.power,.diagnostics].contains(destination)
        if !wanted {
            experimentalRequested=false;workerTask?.cancel();experimentalSamples=[:]
            workerTask=Task {await experimental.stop()}
            experimentalStatus=enabled ? "Enabled; paused until a visible sensor or diagnostics view needs readings.":"Disabled. The optional worker is not enabled."
            capabilities.removeAll {$0.id == "sensors"}
            capabilities.append(Capability("sensors","Apple Silicon sensors",tier:.experimental,availability:.disabled,explanation:experimentalStatus))
            return
        }
        guard !experimentalRequested else {return}
        experimentalRequested=true
        workerTask?.cancel();experimentalSamples=[:]
        capabilities.removeAll {$0.id == "sensors"}
        capabilities.append(Capability("sensors","Apple Silicon sensors",tier:.experimental,availability:enabled ? .warmingUp:.disabled,explanation:enabled ? "Starting isolated provider":"Disabled by default"))
        workerTask=Task {
            await experimental.stop()
            guard enabled else {experimentalStatus="Disabled. The optional worker is not enabled.";return}
            experimentalStatus="Starting signed experimental worker…"
            for await samples in await experimental.samples() {
                guard !Task.isCancelled else {break}
                experimentalSamples=Dictionary(samples.map {($0.id,$0)},uniquingKeysWith:{_,b in b})
                experimentalStatus="Experimental worker running. Hardware comparison is not yet verified."
                capabilities.removeAll {$0.id == "sensors"}
                capabilities.append(Capability("sensors","Apple Silicon sensors",tier:.experimental,availability:.available,explanation:"Worker is producing messages. Check availability and quality on each metric; independent validation remains outstanding."))
            }
            if !Task.isCancelled {
                experimentalSamples=[:]
                let status=await experimental.capabilities().first
                experimentalStatus=status?.explanation ?? "Worker stopped"
                capabilities.removeAll {$0.id == "sensors"}
                capabilities.append(Capability("sensors","Apple Silicon sensors",tier:.experimental,availability:status?.availability ?? .unavailable,explanation:experimentalStatus))
            }
        }
    }
    func enableNotifications() {
        Task {do {let enabled=try await UNUserNotificationCenter.current().requestAuthorization(options:[.alert,.sound]);notificationStatus=enabled ? "Enabled":"Permission denied"} catch {notificationStatus="Unavailable: \(error)"}}
    }
    private func handleAlerts(_ next:TelemetryUpdate) {
        guard UserDefaults.standard.bool(forKey:"alertsEnabled") else {return}
        let threshold=UserDefaults.standard.double(forKey:"memoryAlertThreshold")
        memoryAlert.high=(threshold > 0 ? threshold:90)/100;memoryAlert.reset=max(0,memoryAlert.high-0.05)
        let occupancy=next.snapshot.memory.flatMap {$0.total > 0 ? Double($0.accounted)/Double($0.total):nil}
        let memoryTriggered=memoryAlert.ingest(occupancy),pressureTriggered=pressureAlert.ingest(next.pressure == "Critical" || next.pressure == "Warning" ? 1:next.pressure == "Normal" ? 0:nil)
        guard memoryTriggered || pressureTriggered else {return}
        let content=UNMutableNotificationContent();content.title="Memoria";content.body=pressureTriggered ? "macOS reported elevated memory pressure.":"Accounted active, wired and compressed memory crossed your threshold."
        Task {do {try await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier:UUID().uuidString,content:content,trigger:nil))} catch {notificationStatus="Notification unavailable: \(error)"}}
    }
    private func record(_ metrics:[MetricSample]) {
        guard UserDefaults.standard.bool(forKey:"recordingEnabled") else {recordingStatus="Off";return}
        guard recordTask == nil else {recordingStatus="Recording busy; sample skipped";return}
        recordTask=Task {defer{recordTask=nil};do {try await recording.append(metrics);recordingStatus="Recording aggregate metrics · 25 MB / 7 days"} catch {recordingStatus="Recording failed: \(error)"}}
    }
    func deleteRecordings() {Task {do {try await recording.deleteAll();recordingStatus="Saved recordings deleted"} catch {recordingStatus="Deletion failed: \(error)"}}}
}
enum Format {
    static func percent(_ value:Double?) -> String {value.map {String(format:"%.1f%%",$0)} ?? "—"}
    static func bytes(_ value:UInt64?) -> String {value.map {ByteCountFormatter.string(fromByteCount:Int64(clamping:$0),countStyle:.memory)} ?? "—"}
    static func rate(_ value:Double?) -> String {guard let value,value.isFinite,value >= 0 else {return "—"};return ByteCountFormatter.string(fromByteCount:Int64(min(value,Double(Int64.max-1024))),countStyle:.file)+"/s"}
}
