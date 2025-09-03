import SwiftUI

// MARK: - App Entrypoint

@main
struct ClipboardHistoryApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            Form {
                Toggle("Auto-Paste after selection", isOn: Binding(
                    get: { appDelegate.history.autoPaste },
                    set: { appDelegate.history.setAutoPaste($0) }
                ))
                Stepper(value: Binding(
                    get: { appDelegate.history.maxItems },
                    set: { appDelegate.history.setMax($0) }
                ), in: 5...500) {
                    Text("Keep \(appDelegate.history.maxItems) items")
                }
                Text("Global hotkey: ⌘⇧V (configurable via code)")
            }
            .padding()
        }
    }
}