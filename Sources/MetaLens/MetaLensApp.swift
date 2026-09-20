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
            CommandGroup(after: .newItem) {
                Button("Apri…") { model.chooseFile() }
                    .keyboardShortcut("o")
                Button("Salva metadati") { model.requestSave() }
                    .keyboardShortcut("s")
                Button("Copia report") { model.copyReport() }
                    .keyboardShortcut("c", modifiers: [.command, .shift])
            }
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
