import AppKit
import SwiftUI

@main
struct MetaLensApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model = AppModel.shared

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .frame(minWidth: 780, minHeight: 480)
                .task { model.openFromCommandLine() }
        }
        .defaultSize(width: 1040, height: 700)
        .commands {
            CommandGroup(replacing: .newItem) {}
            FileCommands()
            SidebarCommands()
        }
    }
}

/// The toolbar actions, mirrored in the menu bar: people can hide the toolbar, and the
/// menu bar is where they look for commands and keyboard shortcuts.
struct FileCommands: Commands {
    @FocusedValue(\.fileActions) private var actions

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Apri…") { actions?.open?() }
                .keyboardShortcut("o")
                .disabled(actions?.open == nil)
            Button("Salva") { actions?.save?() }
                .keyboardShortcut("s")
                .disabled(actions?.save == nil)
        }
        CommandGroup(after: .pasteboard) {
            Button("Copia report") { actions?.copyReport?() }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(actions?.copyReport == nil)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// "Apri con MetaLens" from the Finder.
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let first = urls.first else { return }
        Task { @MainActor in AppModel.shared.load(first) }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
