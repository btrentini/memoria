import SwiftUI
import AppKit
import MemoriaCore
import MemoriaCollectors
import MemoriaServices

private struct RankingRefresh:Hashable {
    let preferences:ProcessListPreferences
    let sampledAt:Double?
    let scannedAt:Date?
}
struct ProcessView:View {
    @Bindable var model:AppModel
    let context:ProcessListContext
    @State private var rows:[ProcessSnapshot]=[]
    @State private var loading=false
    @State private var error:String?
    @State private var filtersVisible=false
    private var preferences:ProcessListPreferences {model.processListPreferences[context] ?? ProcessListPreferences(context:context)}
    private var controls:Binding<ProcessListPreferences> {
        Binding(get:{preferences},set:{model.setProcessListPreferences($0,for:context)})
    }
    private var tree:Bool {preferences.tree && (context == .processes || context == .quick)}
    private var refresh:RankingRefresh {RankingRefresh(preferences:preferences,sampledAt:model.snapshot?.monotonic,scannedAt:model.scan?.date)}
    private var selectedInRows:Bool {rows.contains {$0.identity == model.selected}}
    var body:some View {
        VStack(spacing:0) {
            HStack(spacing:10) {
                Text(tree ? "Process tree":"Ranked processes").font(.headline)
                Spacer(minLength:4)
                Picker("Rank by",selection:controls.sort) {
                    ForEach(ProcessSort.allCases,id:\.self) {Text($0.title).tag($0)}
                }.frame(width:210).accessibilityIdentifier("process-sort-"+context.rawValue)
                Button {controls.descending.wrappedValue.toggle()} label:{
                    Image(systemName:preferences.descending ? "arrow.down":"arrow.up")
                }.help(preferences.descending ? "Descending order; click for ascending":"Ascending order; click for descending")
                    .accessibilityLabel(preferences.descending ? "Sort descending":"Sort ascending")
                Button {filtersVisible.toggle()} label:{Label("Filters",systemImage:"line.3.horizontal.decrease")}
                    .popover(isPresented:$filtersVisible) {filterControls}
            }.padding(.horizontal,14).padding(.top,12).padding(.bottom,8)
            HStack {
                Image(systemName:"magnifyingglass").foregroundStyle(.secondary)
                TextField("Search name, PID, path or port",text:controls.query).textFieldStyle(.plain)
                    .accessibilityIdentifier(context == .processes ? "process-search":"process-search-"+context.rawValue)
                if !preferences.query.isEmpty {Button {controls.query.wrappedValue=""} label:{Image(systemName:"xmark.circle.fill")}.buttonStyle(.plain).help("Clear search")}
                Picker("Scope",selection:controls.scope) {ForEach(ProcessScope.allCases,id:\.self) {Text($0.rawValue).tag($0)}}
                    .labelsHidden().frame(width:145).accessibilityLabel("Process scope")
                Menu {
                    if context == .processes || context == .quick {Toggle("Process tree",isOn:controls.tree)}
                    Toggle("Owner",isOn:controls.showOwner);Toggle("Threads",isOn:controls.showThreads)
                    Toggle("Resident memory",isOn:controls.showResident);Toggle("Process I/O",isOn:controls.showIO)
                } label:{Image(systemName:"slider.horizontal.3")}.menuStyle(.borderlessButton).frame(width:25).help("Visible columns and layout")
            }.padding(.horizontal,14).padding(.bottom,8)
            if (try? PortQuery(preferences.query)) != nil {
                HStack {Text("Port matches use the latest socket scan; numeric searches also match PIDs.").font(.caption).foregroundStyle(.secondary);Spacer();Button("Refresh ports") {model.refreshPorts()}.controlSize(.small)}.padding(.horizontal,14).padding(.bottom,6)
            }
            Divider()
            Group {
                if tree {
                    NativeProcessOutline(model:model,rows:rows,context:context,sort:preferences.sort,descending:preferences.descending,sortChanged:sortChanged)
                } else {
                    NativeProcessTable(model:model,rows:rows,context:context,preferences:preferences,sortChanged:sortChanged)
                }
            }.overlay {
                if rows.isEmpty {
                    VStack(spacing:6) {
                        Text(model.sleeping ? "Monitoring paused":loading || model.snapshot == nil ? "Waiting for processes…":error == nil ? "No matching processes":"Process list unavailable").font(.headline)
                        Text(error ?? "Adjust the search, scope or resource filters.").font(.caption).foregroundStyle(.secondary)
                        if model.snapshot != nil {Button("Reset list") {model.setProcessListPreferences(ProcessListPreferences(context:context),for:context)}}
                    }.padding().background(.regularMaterial,in:RoundedRectangle(cornerRadius:10))
                }
            }
            Divider()
            VStack(alignment:.leading,spacing:4) {
                HStack {
                    Text("\(rows.count) of \(model.snapshot?.processes.count ?? 0) visible processes").font(.caption).foregroundStyle(.secondary)
                    if loading {ProgressView().controlSize(.mini)}
                    Spacer()
                    if model.operationRunning {Button("Cancel") {model.cancelOperation()}}
                    Button("Quit App") {model.quitSelected()}.disabled(!selectedInRows || model.selectedProcess == nil || model.operationRunning || loading)
                    Button("Terminate…") {model.prepare(.terminate)}.disabled(!selectedInRows || model.selectedProcess == nil || model.operationRunning || loading)
                    Button("Force Kill…",role:.destructive) {model.prepare(.forceKill)}.disabled(!selectedInRows || model.selectedProcess == nil || model.operationRunning || loading)
                }.controlSize(.small)
                Text(context.note).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
                Text(tree ? "Sorting orders siblings; filtering can hide ancestors.":"# is the position in the filtered order. Unavailable measurements (—) stay last in either direction.")
                    .font(.caption2).foregroundStyle(.secondary)
            }.padding(.horizontal,14).padding(.vertical,8)
        }
        .accessibilityIdentifier("process-list-"+context.rawValue)
        .task(id:refresh) {await refreshRows()}
    }
    private var filterControls:some View {
        Form {
            Picker("Minimum CPU",selection:controls.minimumCPU) {
                ForEach([0.0,1,5,10,50,100],id:\.self) {Text($0 == 0 ? "Any":"\(Int($0))% of one core").tag($0)}
            }
            Picker("Minimum footprint",selection:controls.minimumMemory) {
                ForEach([UInt64(0),50*1_048_576,100*1_048_576,500*1_048_576,1_073_741_824],id:\.self) {Text($0 == 0 ? "Any":Format.bytes($0)).tag($0)}
            }
            Picker("State",selection:controls.state) {
                Text("Any state").tag("")
                ForEach(["Idle","Running","Sleeping","Stopped","Zombie"],id:\.self) {Text($0).tag($0)}
            }
            if preferences.sort.isResource {
                Picker("\(preferences.sort.title) values",selection:controls.values) {
                    ForEach(ProcessValueFilter.allCases,id:\.self) {Text($0.rawValue).tag($0)}
                }
            }
            Button("Reset list") {model.setProcessListPreferences(ProcessListPreferences(context:context),for:context)}
            Text("Filters combine. Controls are remembered for this tab; search text stays in this session.").font(.caption).foregroundStyle(.secondary)
        }.formStyle(.grouped).frame(width:350).padding(8)
    }
    private func sortChanged(_ field:ProcessSort,_ descending:Bool) {
        var value=preferences;value.sort=field;value.descending=descending
        model.setProcessListPreferences(value,for:context)
    }
    private func refreshRows() async {
        guard let snapshot=model.snapshot else {rows=[];loading=false;error=nil;return}
        let input=snapshot.processes,settings=preferences,scan=model.scan,uid=getuid()
        loading=true;error=nil
        do {
            let result=try await model.executor.run {settings.apply(to:input,currentUID:uid,scan:scan)}
            guard !Task.isCancelled else {return}
            rows=result;loading=false
        } catch {
            guard !Task.isCancelled else {return}
            rows=[];loading=false;self.error=String(describing:error)
        }
    }
}
struct NativeProcessTable:NSViewRepresentable {
    var model:AppModel
    let rows:[ProcessSnapshot]
    let context:ProcessListContext
    let preferences:ProcessListPreferences
    let sortChanged:(ProcessSort,Bool)->Void
    func makeCoordinator() -> Coordinator {Coordinator(model:model,sortChanged:sortChanged)}
    func makeNSView(context:Context) -> NSScrollView {
        let scroll=NSScrollView(),table=NSTableView()
        table.delegate=context.coordinator;table.dataSource=context.coordinator;table.usesAlternatingRowBackgroundColors=true;table.rowHeight=33;table.style = .fullWidth
        table.allowsMultipleSelection=false;table.allowsColumnReordering=true;table.allowsColumnResizing=true;table.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        let definitions:[(String,String,CGFloat)]=[("rank","#",55),("name","Process",230),("pid","PID",70),("cpu","CPU %",85),("memory","Footprint",110),("resident","Resident",110),("owner","UID",70),("threads","Threads",70),("io","Read + write/s",120),("read","Read/s",100),("write","Write/s",100),("state","State",100)]
        for (id,title,width) in definitions {let c=NSTableColumn(identifier:NSUserInterfaceItemIdentifier(id));c.title=title;c.width=width;c.minWidth=55;if ProcessSort(rawValue:id) != nil {c.sortDescriptorPrototype=NSSortDescriptor(key:id,ascending:false)};table.addTableColumn(c)}
        table.autosaveName="MemoriaProcessColumns."+self.context.rawValue;table.autosaveTableColumns=true
        table.setAccessibilityLabel("Ranked processes");table.setAccessibilityIdentifier("process-ranking-"+self.context.rawValue)
        let menu=NSMenu()
        for (title,selector) in [("Inspect",#selector(Coordinator.inspect)),("Copy PID",#selector(Coordinator.copyPID)),("Reveal Executable",#selector(Coordinator.reveal)),("Terminate…",#selector(Coordinator.terminate)),("Force Kill…",#selector(Coordinator.force)),("Review Process Tree…",#selector(Coordinator.tree))] {let item=NSMenuItem(title:title,action:selector,keyEquivalent:"");item.target=context.coordinator;menu.addItem(item)}
        table.menu=menu;table.target=context.coordinator;table.doubleAction=#selector(Coordinator.inspect)
        context.coordinator.table=table;scroll.documentView=table;scroll.hasVerticalScroller=true;scroll.hasHorizontalScroller=true;scroll.autohidesScrollers=true;return scroll
    }
    func updateNSView(_ scroll:NSScrollView,context:Context) {
        guard let table=scroll.documentView as? NSTableView else {return}
        let c=context.coordinator;c.updating=true;defer{c.updating=false}
        c.rows=rows;c.sortChanged=sortChanged;table.reloadData()
        let descriptor=NSSortDescriptor(key:preferences.sort.rawValue,ascending:!preferences.descending)
        if table.sortDescriptors != [descriptor] {table.sortDescriptors=[descriptor]}
        for column in table.tableColumns {
            let key=column.identifier.rawValue
            let shown:Bool=switch key {
            case "owner":preferences.showOwner
            case "threads":preferences.showThreads
            case "resident":preferences.showResident
            case "io","read","write":preferences.showIO
            default:true
            }
            column.isHidden = !shown && key != preferences.sort.rawValue
        }
        let index=c.rows.firstIndex {$0.identity == model.selected}
        if let index,table.selectedRow != index {table.selectRowIndexes(IndexSet(integer:index),byExtendingSelection:false)}
        else if index == nil && table.selectedRow >= 0 {table.deselectAll(nil)}
    }
    @MainActor final class Coordinator:NSObject,NSTableViewDelegate,NSTableViewDataSource {
        let model:AppModel
        var rows:[ProcessSnapshot]=[]
        weak var table:NSTableView?
        var updating=false
        var sortChanged:(ProcessSort,Bool)->Void
        init(model:AppModel,sortChanged:@escaping (ProcessSort,Bool)->Void) {self.model=model;self.sortChanged=sortChanged}
        func numberOfRows(in tableView:NSTableView) -> Int {rows.count}
        func tableView(_ tableView:NSTableView,viewFor tableColumn:NSTableColumn?,row:Int) -> NSView? {
            guard rows.indices.contains(row),let column=tableColumn else {return nil}
            let p=rows[row],id=column.identifier
            let cell=(tableView.makeView(withIdentifier:id,owner:self) as? NSTableCellView) ?? NSTableCellView()
            if cell.textField == nil {
                let field=NSTextField(labelWithString:"");field.translatesAutoresizingMaskIntoConstraints=false;field.lineBreakMode = .byTruncatingTail
                cell.addSubview(field);cell.textField=field;cell.identifier=id
                NSLayoutConstraint.activate([field.leadingAnchor.constraint(equalTo:cell.leadingAnchor,constant:8),field.trailingAnchor.constraint(equalTo:cell.trailingAnchor,constant:-8),field.centerYAnchor.constraint(equalTo:cell.centerYAnchor)])
            }
            let text:String=switch id.rawValue {case "rank":String(row+1);case "name":p.name;case "pid":String(p.identity.pid);case "cpu":Format.percent(p.cpuPercent);case "memory":Format.bytes(p.footprintBytes);case "resident":Format.bytes(p.residentBytes);case "io":Format.rate(ProcessSort.io.value(in:p));case "owner":String(p.uid);case "threads":p.threads.map(String.init) ?? "—";case "read":Format.rate(p.readRate);case "write":Format.rate(p.writeRate);case "state":p.state;default:""}
            cell.textField?.stringValue=text;cell.textField?.font=id.rawValue == "name" ? .systemFont(ofSize:13,weight:.medium):.monospacedDigitSystemFont(ofSize:12,weight:.regular)
            cell.textField?.textColor=id.rawValue == "name" ? .labelColor:.secondaryLabelColor
            cell.toolTip=id.rawValue == "cpu" ? "100% equals one fully occupied core. Missing values are not zero.":id.rawValue == "memory" ? "Physical footprint from process accounting.":p.executable?.path
            return cell
        }
        func tableViewSelectionDidChange(_ notification:Notification) {guard !updating,let table else{return};model.selected=rows.indices.contains(table.selectedRow) ? rows[table.selectedRow].identity:nil}
        func tableView(_ tableView:NSTableView,sortDescriptorsDidChange oldDescriptors:[NSSortDescriptor]) {guard !updating,let sort=tableView.sortDescriptors.first,let key=sort.key,let field=ProcessSort(rawValue:key) else{return};sortChanged(field,!sort.ascending)}
        private func useClicked() {guard let table else{return};let row=table.clickedRow >= 0 ? table.clickedRow:table.selectedRow;if rows.indices.contains(row) {model.selected=rows[row].identity}}
        @objc func inspect() {useClicked();model.inspectorVisible=true;model.loadDetails()}
        @objc func copyPID() {useClicked();if let p=model.selectedProcess {NSPasteboard.general.clearContents();NSPasteboard.general.setString(String(p.identity.pid),forType:.string)}}
        @objc func reveal() {useClicked();if let path=model.selectedProcess?.executable?.path {NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath:path)])}}
        @objc func terminate() {useClicked();model.prepare(.terminate)}
        @objc func force() {useClicked();model.prepare(.forceKill)}
        @objc func tree() {useClicked();model.prepare(.terminate,tree:true)}
    }
}
struct InspectorView:View {
    @Bindable var model:AppModel
    var body:some View {ScrollView {VStack(alignment:.leading,spacing:20) {
        HStack {Text("Inspector").font(.headline);Spacer();Button {model.inspectorVisible=false} label:{Image(systemName:"xmark")}.buttonStyle(.plain).help("Close inspector")}
        if let p=model.selectedProcess {
            Image(systemName:"app.fill").font(.system(size:42)).foregroundStyle(.tint)
            Text(p.name).font(.title2.weight(.semibold)).textSelection(.enabled)
            Text("PID \(p.identity.pid) · \(p.state)").foregroundStyle(.secondary)
            Divider()
            LabeledContent("CPU · one core",value:Format.percent(p.cpuPercent))
            LabeledContent("CPU · whole machine",value:Format.percent(p.cpuPercent.flatMap {DeltaMath.machineCPU(oneCore:$0,coreCount:model.snapshot?.cpuTicks.count ?? 0)}))
            LabeledContent("Physical footprint",value:Format.bytes(p.footprintBytes))
            LabeledContent("Resident memory",value:Format.bytes(p.residentBytes))
            Button(model.pinned.contains(p.identity) ? "Unpin History":"Pin History") {model.togglePin(p.identity)}
            if let history=model.processHistories[p.identity]?["cpu"] {ChartPanel(title:"Selected process CPU (%)",points:history.downsample(window:300,endingAt:model.snapshot?.monotonic ?? 0))}
            LabeledContent("Parent PID",value:String(p.parentPID));LabeledContent("Owner UID",value:String(p.uid));LabeledContent("Threads",value:p.threads.map(String.init) ?? "—")
            LabeledContent("Started",value:Date(timeIntervalSince1970:Double(p.identity.startSeconds)).formatted(date:.abbreviated,time:.standard))
            Divider()
            Text(p.executable?.path ?? "Executable unavailable").font(.caption).textSelection(.enabled)
            if let path=p.executable?.path {Button("Reveal Executable") {NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath:path)])}}
            Button("Load Arguments…") {model.loadDetails(includeArguments:true)}.help("Arguments can contain credentials or other sensitive data. They are never recorded automatically.")
            if model.detailLoading {ProgressView().controlSize(.small)}
            if !model.detailText.isEmpty {Text(model.detailText).font(.caption.monospaced()).textSelection(.enabled)}
            ForEach(p.errors.keys.sorted(),id:\.self) {key in Text("\(key): system error \(p.errors[key] ?? 0)").font(.caption).foregroundStyle(.secondary)}
            Button("Review Process Tree…") {model.prepare(.terminate,tree:true)}
            if HelperConfiguration.team != nil {Menu("Administrator Action…") {Button("Authorise SIGTERM…") {model.prepareAdministrator(.terminate)};Button("Authorise SIGKILL…") {model.prepareAdministrator(.forceKill)}}}
            if let target=TerminationTarget(process:p) {Menu("Copy Terminal Command") {Button("SIGTERM command") {copyCommand(target,.terminate)};Button("SIGKILL command") {copyCommand(target,.forceKill)}}}
            Text("Copied commands do not retain identity checks. They are never executed automatically.").font(.caption2).foregroundStyle(.secondary)
            if let scan=model.scan {let endpoints=scan.endpoints.filter {$0.process == p.identity};Text("Sockets (last scan)").font(.headline);ForEach(endpoints) {e in Text("\(e.transport.rawValue) \(e.localDisplay) · \(e.state)").font(.caption)}}
            Button("Refresh Sockets") {model.refreshPorts()}
        } else {ContentUnavailableView("Select a process",systemImage:"cursorarrow.click",description:Text("Inspect identity, resources and available actions."));Text("Only fields exposed by macOS are shown. An inaccessible field remains unavailable.").font(.caption).foregroundStyle(.secondary)}
    }.padding(20)}}
    func copyCommand(_ target:TerminationTarget,_ action:TerminationAction) {guard let command=ActionPolicy.command(for:target,action:action) else{return};NSPasteboard.general.clearContents();NSPasteboard.general.setString(command,forType:.string)}
}
struct ActionConfirmation:View {
    @Bindable var model:AppModel
    let review:ActionReview
    @State private var selected:Set<ProcessIdentity>=[]
    @Environment(\.dismiss) private var dismiss
    var body:some View {VStack(alignment:.leading,spacing:18) {
        Label(review.query.map {"Free Port \($0.port)"} ?? review.action.title,systemImage:review.action == .forceKill ? "exclamationmark.triangle":"stop.circle").font(.title2.weight(.semibold))
        Text(review.action == .forceKill ? "Force killing stops the selected processes immediately. Unsaved work may be lost.":"SIGTERM requests termination. The process may refuse or continue running; Memoria will not automatically escalate.")
        Text("Every selected identity and executable will be checked again before signalling. The final PID-based signal still has a residual race window.").font(.caption).foregroundStyle(.secondary)
        if review.administrator {Text("This operation requires separate administrator authorisation through the signed helper.").font(.callout.weight(.medium))}
        ScrollView {VStack(alignment:.leading,spacing:12) {ForEach(review.targets) {target in Toggle(isOn:Binding(get:{selected.contains(target.identity)},set:{if $0 {selected.insert(target.identity)} else {selected.remove(target.identity)}})) {VStack(alignment:.leading,spacing:3) {Text("\(target.name) · PID \(target.identity.pid)");Text(target.executable.path).font(.caption).foregroundStyle(.secondary)}}}}}.frame(maxHeight:260)
        if review.treeRoot != nil {Text("Tree membership is a snapshot. Descendants are listed before the parent. Shared or inferred helpers are initially excluded.").font(.caption).foregroundStyle(.secondary)}
        HStack {Spacer();Button("Cancel",role:.cancel) {dismiss()}.keyboardShortcut(.cancelAction);Button(review.action == .forceKill ? "Force Kill Selected":"Terminate Selected",role:.destructive) {model.perform(review,selected:selected)}.disabled(selected.isEmpty).keyboardShortcut(.defaultAction)}
    }.padding(26).frame(width:620).onAppear {
        if let root=review.treeRoot,let process=model.snapshot?.processes.first(where:{$0.identity == root}) {
            let bundle=process.executable.flatMap {ApplicationGrouping.bundlePath($0.path)}
            selected=Set(review.targets.filter {$0.identity == root || (bundle != nil && ApplicationGrouping.bundlePath($0.executable.path) == bundle)}.map(\.identity))
        } else {selected=Set(review.targets.map(\.identity))}
    }}
}
struct PortsView:View {
    @Bindable var model:AppModel
    var query:PortQuery? {try? PortQuery(model.portInput)}
    var endpoints:[EndpointRecord] {(model.scan?.endpoints ?? []).filter {(!model.listenersOnly || $0.isListener) && (model.portInput.isEmpty || query?.matches($0) == true)}}
    var body:some View {VStack(spacing:0) {
        HStack {TextField("Port, :8080, localhost:8080, [::1]:8080 or URL",text:$model.portInput).textFieldStyle(.roundedBorder);Toggle("Listeners",isOn:$model.listenersOnly).toggleStyle(.checkbox);Button("Refresh") {model.refreshPorts()}.disabled(model.scanning);Menu {Button("Run bounded lsof fallback") {model.refreshPorts(fallback:true)}} label:{Image(systemName:"ellipsis.circle")}.menuStyle(.borderlessButton).frame(width:25)}.padding(16)
        if !model.portInput.isEmpty && query == nil {Text("Enter a valid port from 1 to 65535, or a supported address / URL.").foregroundStyle(.orange).padding(.bottom,12)}
        if model.scanning {ProgressView("Inspecting socket ownership…").padding()}
        ScrollView {LazyVStack(alignment:.leading,spacing:14) {ForEach(endpoints) {e in GroupBox {VStack(alignment:.leading,spacing:10) {HStack {Text(e.localDisplay).font(.headline.monospaced());Text(e.transport.rawValue).font(.caption);Spacer();Text(e.state).font(.caption).foregroundStyle(.secondary)};HStack {Button("\(e.processName) · \(e.process.pid)") {model.selected=e.process;model.inspectorVisible=true};Spacer();if e.isListener {Button("Free Port…") {model.prepareFreePort(e)}.disabled(model.operationRunning)}};if e.remotePort > 0 {Text("Remote \(e.remoteAddress):\(e.remotePort)").font(.caption).foregroundStyle(.secondary)}}.padding(10)}};if endpoints.isEmpty && !model.scanning {ContentUnavailableView("No matching visible endpoints",systemImage:"network",description:Text(model.scan == nil ? "Refresh to inspect local sockets.":"A partial scan cannot prove that a port is free."))}}.padding(16)}
        Divider();Text(model.scan?.coverage ?? "No scan yet. Full socket discovery runs on demand.").font(.caption).foregroundStyle(.secondary).frame(maxWidth:.infinity,alignment:.leading).padding(14)
    }.onAppear {if model.scan == nil {model.refreshPorts()}}}
}
struct QuickView:View {
    @Bindable var model:AppModel
    var body:some View {VStack(spacing:0) {HStack {Label("Quick Task Manager",systemImage:"bolt.square.fill").font(.title3.weight(.semibold));Spacer();Text("CPU \(model.cpuText)").monospacedDigit();Text(Format.bytes(model.snapshot?.memory?.accounted)).foregroundStyle(.secondary)}.padding(16);Divider();ProcessView(model:model,context:.quick)}.frame(minWidth:700,minHeight:400).sheet(item:Binding(get:{model.reviewPresenter == "quick" ? model.review:nil},set:{model.review=$0})) {ActionConfirmation(model:model,review:$0)}.alert("Operation result",isPresented:Binding(get:{model.reviewPresenter == "quick" && !model.resultMessage.isEmpty},set:{if !$0 {model.resultMessage=""}})) {Button("OK") {model.resultMessage=""}} message:{Text(model.resultMessage)}.task {model.start()}}
}
struct CommandPalette:View {
    @Bindable var model:AppModel
    @State private var query=""
    @Environment(\.dismiss) private var dismiss
    var body:some View {VStack(alignment:.leading) {TextField("Jump to a view…",text:$query).textFieldStyle(.roundedBorder).padding();List(Destination.allCases.filter {query.isEmpty || $0.rawValue.localizedCaseInsensitiveContains(query)}) {destination in Button {model.destination=destination;dismiss()} label:{Label(destination.rawValue,systemImage:destination.symbol)}.buttonStyle(.plain)}}.frame(width:440,height:460)}
}
