import SwiftUI

// The app supports macOS 14 and up. Everything newer lives here behind `#available`,
// so the call sites stay one line and the fallback is written once.

extension View {
    /// Tinted Liquid Glass for the one primary toolbar action; a bordered prominent button before macOS 26.
    @ViewBuilder
    func prominentToolbarButton() -> some View {
        if #available(macOS 26, *) {
            buttonStyle(.glassProminent)
        } else {
            buttonStyle(.borderedProminent)
        }
    }
}

extension ToolbarContent {
    /// Items that shouldn't sit in the shared glass capsule (the spinner); older toolbars have no capsule.
    @ToolbarContentBuilder
    func withoutSharedBackground() -> some ToolbarContent {
        if #available(macOS 26, *) {
            sharedBackgroundVisibility(.hidden)
        } else {
            self
        }
    }
}

/// A gap between toolbar groups on macOS 26; older toolbars have no glass groups to separate.
struct ToolbarGap: ToolbarContent {
    var body: some ToolbarContent {
        if #available(macOS 26, *) {
            ToolbarSpacer(.fixed)
        }
    }
}

/// What the menu bar can do with the frontmost window. A nil action means the command is disabled.
struct FileActions {
    var open: (() -> Void)?
    var save: (() -> Void)?
    var copyReport: (() -> Void)?
}

struct FileActionsKey: FocusedValueKey {
    typealias Value = FileActions
}

extension FocusedValues {
    var fileActions: FileActions? {
        get { self[FileActionsKey.self] }
        set { self[FileActionsKey.self] = newValue }
    }
}
