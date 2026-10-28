import SwiftUI
import MemoriaCore

struct ApplicationsView:View {
    @Bindable var model:AppModel
    @State private var query=""
    @AppStorage("applicationGroupSort") private var sort="memory"
    @AppStorage("applicationGroupDescending") private var descending=true
    private var groups:[ApplicationGroup] {
        let text=query.trimmingCharacters(in:.whitespacesAndNewlines)
        return model.groups.filter {group in
            text.isEmpty || group.name.localizedCaseInsensitiveContains(text) || group.members.contains {
                $0.process.name.localizedCaseInsensitiveContains(text) || String($0.process.identity.pid) == text
            }
        }.sorted {a,b in
            if sort == "name",a.name != b.name {
                return descending ? a.name.localizedStandardCompare(b.name) == .orderedDescending:a.name.localizedStandardCompare(b.name) == .orderedAscending
            }
            let left=sort == "cpu" ? a.cpuPercent:a.footprintSum.map(Double.init)
            let right=sort == "cpu" ? b.cpuPercent:b.footprintSum.map(Double.init)
            if sort != "name",left != right {
                guard let left else {return false};guard let right else {return true}
                return descending ? left > right:left < right
            }
            return a.id < b.id
        }
    }
    var body:some View {
        VStack(alignment:.leading,spacing:10) {
            HStack {
                TextField("Find an application or process",text:$query).textFieldStyle(.roundedBorder)
                Picker("Rank applications by",selection:$sort) {
                    Text("Memory").tag("memory");Text("CPU").tag("cpu");Text("Name").tag("name")
                }.labelsHidden().frame(width:110)
                Button {descending.toggle()} label:{Image(systemName:descending ? "arrow.down":"arrow.up")}
                    .help("Reverse application order").accessibilityLabel("Reverse application order")
            }
            HStack {
                Button("Expand All") {model.expandedApplications.formUnion(groups.map(\.id))}
                Button("Collapse All") {model.expandedApplications.subtract(groups.map(\.id))}
                Spacer()
            }.controlSize(.small)
            ApplicationMemoryCaption(date:model.applicationMemory.date)
            ScrollView {
                LazyVStack(alignment:.leading,spacing:12) {
                    if groups.isEmpty {
                        ContentUnavailableView("No matching applications",systemImage:"app.dashed",description:Text("Unassigned processes are available in the process table."))
                    }
                    ForEach(groups) {group in
                        ApplicationGroupCard(group:group,isExpanded:Binding(
                            get:{model.expandedApplications.contains(group.id)},
                            set:{if $0 {model.expandedApplications.insert(group.id)} else {model.expandedApplications.remove(group.id)}}),
                            operationRunning:model.operationRunning,
                            inspect:{model.selected=$0.identity;model.inspectorVisible=true},
                            closeProcess:{model.prepareApplicationProcess($0,action:$1)},
                            closeApplication:{model.prepareApplication(group.bundlePath,action:$0)})
                    }
                    Text("Footprints are process-accounting sums, not unique RAM. Bundle members are identified by executable path; ancestry is inferred. Shared services remain unassigned. New processes show — for memory until the next refresh.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }.padding(20).accessibilityIdentifier("application-groups")
    }
}

struct ApplicationMemoryCaption:View {
    let date:Date?
    var body:some View {
        Text(date.map {"Memory updated \($0.formatted(date:.omitted,time:.standard)) · every 5 minutes. CPU and membership stay live."} ?? "Waiting for memory readings · refreshed every 5 minutes.")
            .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
            .accessibilityIdentifier("application-memory-cadence")
    }
}

struct ApplicationGroupCard:View {
    let group:ApplicationGroup
    @Binding var isExpanded:Bool
    let operationRunning:Bool
    let inspect:(ProcessSnapshot)->Void
    let closeProcess:(ProcessSnapshot,TerminationAction)->Void
    let closeApplication:(TerminationAction)->Void
    var body:some View {
        GroupBox {
            DisclosureGroup(isExpanded:$isExpanded) {
                VStack(spacing:10) {
                    ForEach(group.members.sorted {$0.process.identity.pid < $1.process.identity.pid},id:\.process.identity) {member in
                        Divider()
                        HStack(alignment:.top) {
                            Button {inspect(member.process)} label:{
                                VStack(alignment:.leading,spacing:5) {
                                    Text(member.process.name).font(.body.weight(.medium)).lineLimit(1)
                                    Text("PID \(member.process.identity.pid) · \(member.membership == .exact ? "Bundle member":"Inferred ancestry")")
                                        .font(.caption).foregroundStyle(.secondary)
                                    HStack {Text("CPU \(Format.percent(member.process.cpuPercent))");Text("Memory \(Format.bytes(member.process.footprintBytes))")}
                                        .font(.caption).monospacedDigit().foregroundStyle(.secondary)
                                }.frame(maxWidth:.infinity,alignment:.leading).contentShape(Rectangle())
                            }.buttonStyle(.plain).help("Inspect this process")
                            Menu {
                                Button("Close Process…",role:.destructive) {closeProcess(member.process,.terminate)}
                                Button("Force Kill Process…",role:.destructive) {closeProcess(member.process,.forceKill)}
                            } label:{Image(systemName:"xmark.circle")}
                                .menuStyle(.borderlessButton).frame(width:28).disabled(operationRunning)
                                .accessibilityLabel("Close process \(member.process.name)")
                                .help("Close only this process")
                        }
                    }
                }.padding(.top,8)
            } label:{
                VStack(alignment:.leading,spacing:8) {
                    HStack {
                        Label(group.name,systemImage:"app.fill").font(.headline).lineLimit(1)
                        Spacer(minLength:8)
                        Menu {
                            Button("Close Application and Processes…",role:.destructive) {closeApplication(.terminate)}
                            Button("Force Kill Application and Processes…",role:.destructive) {closeApplication(.forceKill)}
                        } label:{Image(systemName:"xmark.circle.fill")}
                            .menuStyle(.borderlessButton).frame(width:28).disabled(operationRunning)
                            .accessibilityLabel("Close application \(group.name) and its processes")
                            .help("Review all processes belonging to this application")
                    }
                    HStack {
                        Text("\(group.members.count) processes")
                        Spacer(minLength:4)
                        Text("CPU \(Format.percent(group.cpuPercent))")
                        Text("Memory \(Format.bytes(group.footprintSum))")
                    }.font(.caption).monospacedDigit().foregroundStyle(.secondary)
                    if group.accountingIncomplete {Text("Partial resource accounting").font(.caption2).foregroundStyle(.secondary)}
                }
            }.padding(8)
        }.accessibilityIdentifier("application-group")
    }
}
