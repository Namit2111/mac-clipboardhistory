
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let hotKey = HotKeyManager()
    let history = ClipboardHistory()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        history.loadPersisted()
        history.start()

        // Wire the popover content
        let root = ContentView()
            .environmentObject(history)
            .environmentObject(hotKey)
        StatusItemController.shared.setRootView(root)

        // Register ⌘⇧V
        hotKey.registerDefaultHotKey()
    }

    func applicationWillTerminate(_ notification: Notification) {
        history.stop()
    }
}
