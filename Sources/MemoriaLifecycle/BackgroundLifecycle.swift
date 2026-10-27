import AppKit
import Foundation
import Observation
import ServiceManagement
import SwiftUI

public enum LoginItemState:String,Sendable {case disabled,enabled,approvalRequired,unavailable}
@MainActor public protocol LoginItemManaging:AnyObject {
    var state:LoginItemState {get}
    var registrationAllowed:Bool {get}
    func register() throws
    func unregister() async throws
    func openSettings()
}
public enum LoginInstallation {
    public static func isPermanent(_ application:URL,roots:[URL]) -> Bool {
        let url=application.standardizedFileURL.resolvingSymlinksInPath()
        guard url.pathExtension=="app" else {return false}
        return roots.contains {root in
            let base=root.standardizedFileURL.resolvingSymlinksInPath().path
            return url.path.hasPrefix(base+"/")
        }
    }
}
@MainActor public final class SystemLoginItemManager:LoginItemManaging {
    public init() {}
    public var state:LoginItemState {
        switch SMAppService.mainApp.status {
        case .notRegistered:return .disabled
        case .enabled:return .enabled
        case .requiresApproval:return .approvalRequired
        case .notFound:return .unavailable
        @unknown default:return .unavailable
        }
    }
    public var registrationAllowed:Bool {
        LoginInstallation.isPermanent(Bundle.main.bundleURL,roots:[URL(fileURLWithPath:"/Applications",isDirectory:true),FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications",isDirectory:true)])
    }
    public func register() throws {try SMAppService.mainApp.register()}
    public func unregister() async throws {try await SMAppService.mainApp.unregister()}
    public func openSettings() {SMAppService.openSystemSettingsLoginItems()}
}
@MainActor @Observable public final class BackgroundLifecycle {
    private let manager:any LoginItemManaging
    public private(set) var loginState:LoginItemState = .disabled
    public private(set) var busy=false
    public private(set) var errorMessage:String?
    public var showDockIcon=UserDefaults.standard.bool(forKey:"showDockIcon") {
        didSet {
            UserDefaults.standard.set(showDockIcon,forKey:"showDockIcon")
            NSApp?.setActivationPolicy(showDockIcon ? .regular:.accessory)
        }
    }
    public init(manager:any LoginItemManaging=SystemLoginItemManager()) {self.manager=manager;refresh()}
    public var loginRequested:Bool {loginState == .enabled || loginState == .approvalRequired}
    public var canRegister:Bool {manager.registrationAllowed}
    public var statusText:String {
        switch loginState {
        case .disabled:return "Launch at login is off."
        case .enabled:return "Memoria will start quietly when you sign in."
        case .approvalRequired:return "Approval is pending in System Settings → General → Login Items."
        case .unavailable:return "Login startup is unavailable for this installation."
        }
    }
    public func refresh() {loginState=manager.state}
    public func setLoginEnabled(_ enabled:Bool) async {
        guard !busy else {return}
        errorMessage=nil;refresh()
        if enabled && !canRegister {errorMessage="Move Memoria to Applications before enabling login startup. Temporary preview copies cannot be registered.";return}
        if enabled && loginRequested || !enabled && loginState == .disabled {return}
        busy=true;defer {busy=false;refresh()}
        do {if enabled {try manager.register()} else {try await manager.unregister()}}
        catch {errorMessage="Login startup could not be changed: "+error.localizedDescription}
    }
    public func openLoginSettings() {manager.openSettings()}
}
@MainActor public final class BackgroundApplicationDelegate:NSObject,NSApplicationDelegate {
    public static let reopenNotification=Notification.Name("MemoriaOpenMonitor")
    public func applicationDidFinishLaunching(_ notification:Notification) {
        NSApp.setActivationPolicy(UserDefaults.standard.bool(forKey:"showDockIcon") ? .regular:.accessory)
    }
    public func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication) -> Bool {false}
    public func applicationShouldHandleReopen(_ sender:NSApplication,hasVisibleWindows:Bool) -> Bool {
        if !hasVisibleWindows {NotificationCenter.default.post(name:Self.reopenNotification,object:nil)}
        return true
    }
}
public struct BackgroundPreferences:View {
    @Bindable var lifecycle:BackgroundLifecycle
    public init(lifecycle:BackgroundLifecycle) {self.lifecycle=lifecycle}
    public var body:some View {
        Section("Background and startup") {
            Toggle("Show Memoria in the Dock",isOn:$lifecycle.showDockIcon)
            Toggle("Launch Memoria at login",isOn:Binding(get:{lifecycle.loginRequested},set:{value in Task {await lifecycle.setLoginEnabled(value)}}))
                .disabled(lifecycle.busy || !lifecycle.canRegister && !lifecycle.loginRequested)
            Text(lifecycle.statusText).font(.caption).foregroundStyle(.secondary)
            if !lifecycle.canRegister {Text("Install Memoria in Applications to enable login startup.").font(.caption).foregroundStyle(.secondary)}
            if let error=lifecycle.errorMessage {Text(error).font(.caption).foregroundStyle(.secondary)}
            Button("Login Items Settings…") {lifecycle.openLoginSettings()}
            Text("Closing the monitor keeps the menu-bar readings running. Use Quit Memoria in its menu to stop. Login startup begins after you sign in and does not open the monitor window.").font(.caption).foregroundStyle(.secondary)
        }.onAppear {lifecycle.refresh()}
            .onReceive(NotificationCenter.default.publisher(for:NSApplication.didBecomeActiveNotification)) {_ in lifecycle.refresh()}
    }
}
