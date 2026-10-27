import SwiftUI
import MemoriaCore

@main struct MemoriaApp:App {
    @State private var model=AppModel()
    @AppStorage("appearance") private var appearance="System"
    var body:some Scene {
        Window("Memoria",id:"main") {
            MainView(model:model)
                .preferredColorScheme(appearance == "Dark" ? .dark:appearance == "Light" ? .light:nil)
                .frame(minWidth:1000,minHeight:650)
                .task {model.start()}
                .onOpenURL {model.handleWidgetURL($0)}
        }
        .defaultSize(width:1320,height:850)
        .commands {
            CommandGroup(after:.newItem) {Button("Quick Task Manager") {model.showQuick()}.keyboardShortcut("k",modifiers:[.command,.shift])}
            CommandMenu("Monitor") {
                Button("Command Palette") {model.commandPalette=true}.keyboardShortcut("k",modifiers:.command)
                Button("Refresh Ports") {model.refreshPorts()}.keyboardShortcut("r",modifiers:.command)
                Divider()
                Button("Quit Selected Application") {model.quitSelected()}.disabled(model.selectedProcess == nil)
                Button("Terminate Selected Process…") {model.prepare(.terminate)}.disabled(model.selectedProcess == nil)
                Button("Force Kill Selected Process…") {model.prepare(.forceKill)}.disabled(model.selectedProcess == nil)
            }
        }
        MenuBarExtra(isInserted:$model.menuBarVisible) {MenuPopover(model:model)} label:{MenuBarStatusLabel(model:model)}
            .menuBarExtraStyle(.window)
        Settings {SettingsView(model:model).frame(width:610,height:600)}
    }
}
