import SwiftUI
import MemoriaServices
import MemoriaLifecycle
import MemoriaWidgetSupport

struct SettingsView:View {
    @Bindable var model:AppModel
    @Bindable var lifecycle:BackgroundLifecycle
    @AppStorage("appearance") private var appearance="System"
    @AppStorage("samplingInterval") private var interval=1.0
    @AppStorage("shortcutEnabled") private var shortcut=true
    @AppStorage("shortcutKey") private var shortcutKey="Escape"
    @AppStorage("recordingEnabled") private var recording=false
    @AppStorage("alertsEnabled") private var alerts=false
    @AppStorage("memoryAlertThreshold") private var threshold=90.0
    @AppStorage("experimentalEnabled") private var experimental=false
    @State private var serviceStatus=AdministratorService.status
    @State private var deletion=false
    @State private var widgetHelp=false
    var body:some View {TabView {
        Form {
            BackgroundPreferences(lifecycle:lifecycle)
            Section("Appearance") {Picker("Theme",selection:$appearance) {ForEach(["System","Light","Dark"],id:\.self) {Text($0)}};Toggle("Simplified main window",isOn:$model.simplifiedView);Text("Charts, key readings and up to ten processes per tab. Switch to Full for detailed tables and actions.").font(.caption).foregroundStyle(.secondary)}
            Section("Menu bar and widgets") {
                Picker("Menu-bar readings",selection:$model.menuBarReading) {ForEach(MenuBarReading.allCases,id:\.rawValue) {Text($0.rawValue).tag($0.rawValue)}}
                Toggle("Share aggregate readings with desktop widgets",isOn:$model.widgetSharing)
                Text(model.widgetStatus).font(.caption).foregroundStyle(.secondary)
                HStack {Button("Widget setup…") {widgetHelp=true};Button("Refresh widget snapshot") {model.publishWidget(force:true)}}
                Text("Keep Memoria running for menu-bar updates. Desktop widgets display timestamped snapshots; macOS schedules refreshes. Sharing stores one small local aggregate snapshot, without process details. Disabling sharing deletes it.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Collection") {Picker("Visible sampling interval",selection:$interval) {Text("1 second").tag(1.0);Text("2 seconds").tag(2.0);Text("5 seconds").tag(5.0);Text("10 seconds").tag(10.0)};Text("Processes refresh every 2 seconds while visible and every 10 seconds in the background. Aggregate collection slows under thermal pressure or Low Power Mode.").font(.caption).foregroundStyle(.secondary)}
            Section("Quick Task Manager") {Toggle("Enable global shortcut",isOn:$shortcut);Picker("Control–Shift +",selection:$shortcutKey) {ForEach(["Escape","F1","F2"],id:\.self) {Text($0)}};Text(model.shortcutStatus).font(.caption).foregroundStyle(.secondary)}
        }.formStyle(.grouped).tabItem {Label("General",systemImage:"gearshape")}
        Form {
            Section("Recording") {Toggle("Save aggregate metrics locally",isOn:$recording);Text("Disabled by default. Maximum 25 MB, retained for 7 days. Process names, arguments and executable paths are excluded.").font(.caption).foregroundStyle(.secondary);Text(model.recordingStatus).font(.caption);Button("Delete Saved Recordings…",role:.destructive) {deletion=true}}
            Section("Memory alerts") {Toggle("Enable memory alerts",isOn:$alerts);Slider(value:$threshold,in:50...99,step:1) {Text("Accounted memory threshold")};Text("Threshold \(Int(threshold))%; resets 5 percentage points below the threshold. Three consecutive readings are required. Pressure alerts use two elevated readings.").font(.caption);Text(model.notificationStatus).font(.caption).foregroundStyle(.secondary)}
        }.formStyle(.grouped).tabItem {Label("History & Alerts",systemImage:"clock")}
        Form {
            Section("Experimental sensors") {Toggle("Enable isolated sensor worker",isOn:$experimental).disabled(HelperConfiguration.team == nil || Bundle.main.url(forAuxiliaryExecutable:"memoria-worker") == nil);Text(model.experimentalStatus);Text("Requires a signed, bundled worker. Metrics are labelled experimental; missing channels remain unavailable. Hardware comparison is a separate verification gate.").font(.caption).foregroundStyle(.secondary)}
            Section("Administrator operations") {Text(serviceStatus);Button("Register Signed Helper…") {do {try AdministratorService.register();serviceStatus=AdministratorService.status} catch {serviceStatus=String(describing:error)}}.disabled(HelperConfiguration.team == nil);Button("Remove Helper") {Task {do {try await AdministratorService.unregister();serviceStatus=AdministratorService.status} catch {serviceStatus=String(describing:error)}}}.disabled(HelperConfiguration.team == nil);Text("Registration and administrator approval are separate from authorisation for each operation. No administrator capability is enabled in unsigned development builds.").font(.caption).foregroundStyle(.secondary)}
            Section("Endpoint Security") {Text("Unavailable until Apple approves entitlement provisioning. Native polling remains active.").foregroundStyle(.secondary)}
        }.formStyle(.grouped).tabItem {Label("Capabilities",systemImage:"checkmark.shield")}
    }.padding(12)
    .sheet(isPresented:$widgetHelp) {WidgetHelpView(model:model)}
    .onChange(of:interval) {_,_ in model.configureSampling()}
    .onChange(of:shortcut) {_,_ in model.configureShortcut()}
    .onChange(of:shortcutKey) {_,_ in model.configureShortcut()}
    .onChange(of:alerts) {_,value in if value {model.enableNotifications()}}
    .onChange(of:experimental) {_,_ in model.configureExperimental()}
    .confirmationDialog("Delete all saved aggregate recordings?",isPresented:$deletion) {Button("Delete Recordings",role:.destructive) {recording=false;model.deleteRecordings()}}
    }
}
