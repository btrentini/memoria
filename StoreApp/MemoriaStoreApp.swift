import SwiftUI
import AppKit
import MemoriaLifecycle
import MemoriaWidgetSupport

@main struct MemoriaStoreApp:App {
    @NSApplicationDelegateAdaptor(BackgroundApplicationDelegate.self) private var delegate
    @State private var lifecycle=BackgroundLifecycle()
    @State private var model=StoreModel()
    var body:some Scene {
        Window("Memoria",id:"monitor") {
            StoreDashboard(model:model)
                .onOpenURL {url in
                    guard let route=WidgetRoute(url:url,expectedScheme:"memoria-store") else {return}
                    model.selection=route == .cpu ? .cpu:route == .memory ? .memory:.overview
                }
        }.defaultSize(width:1120,height:760)
            .defaultLaunchBehavior(.suppressed).restorationBehavior(.disabled)
        Settings {StoreSettings(model:model,lifecycle:lifecycle).frame(width:500)}
        MenuBarExtra {
            StoreMenu(model:model)
        } label: {
            StoreStatusLabel(model:model)
        }.menuBarExtraStyle(.window)
    }
}
struct StoreMenu:View {
    @Bindable var model:StoreModel
    @Environment(\.openWindow) private var openWindow
    var body:some View {
        VStack(alignment:.leading,spacing:14) {
            HStack {Label {Text("Memoria")} icon:{BrandMark()}.font(.headline);Spacer();Text(model.paused ? "Paused":"Live").font(.caption).foregroundStyle(.secondary)}
            HStack {StoreReading(title:"CPU",value:storePercent(model.snapshot?.cpu),symbol:"cpu");StoreReading(title:"Memory",value:storeBytes(model.snapshot?.memory?.accounted),symbol:"memorychip")}
            StoreChart(points:model.history.suffix(30).map {$0},metric:.cpu).frame(height:75)
            Text("Pressure: "+model.pressure.rawValue.capitalized).font(.caption).foregroundStyle(.secondary)
            Divider()
            Button("Open Memoria") {openWindow(id:"monitor");NSApp.activate(ignoringOtherApps:true)}.keyboardShortcut("o")
            Button(model.paused ? "Resume monitoring":"Pause monitoring") {model.togglePaused()}
            SettingsLink()
            Button("Quit Memoria") {NSApp.terminate(nil)}.keyboardShortcut("q")
        }.padding(18).frame(width:340)
    }
}

private struct StoreStatusLabel:View {
    @Bindable var model:StoreModel
    @Environment(\.openWindow) private var openWindow
    var body:some View {
        HStack(spacing:5) {BrandMark();if !model.menuText.isEmpty {Text(model.menuText).monospacedDigit()}}
            .accessibilityLabel("Memoria. "+model.menuText)
            .onReceive(NotificationCenter.default.publisher(for:BackgroundApplicationDelegate.reopenNotification)) {_ in openWindow(id:"monitor");NSApp.activate()}
    }
}
