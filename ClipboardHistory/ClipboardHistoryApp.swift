import SwiftUI
import AppKit
import Combine
import Carbon.HIToolbox // For key codes & modifiers

// MARK: - Models

struct ClipItem: Identifiable, Equatable, Hashable {
    enum Kind: String, Codable { case text, image }
    let id = UUID()
    let kind: Kind
    var text: String? = nil
    var image: NSImage? = nil
    let timestamp: Date = .init()

    var displayTitle: String {
        switch kind {
        case .text:
            let t = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "(empty)"
            return t.isEmpty ? "(empty)" : t.replacingOccurrences(of: "\n", with: " ⏎ ")
        case .image:
            return "Image \(image?.size.width ?? 0)x\(image?.size.height ?? 0)"
        }
    }
}

// MARK: - Clipboard Watcher

final class ClipboardHistory: ObservableObject {
    @Published var items: [ClipItem] = []
    @Published var maxItems: Int = UserDefaults.standard.integer(forKey: "maxItems") == 0 ? 50 : UserDefaults.standard.integer(forKey: "maxItems")
    @Published var autoPaste: Bool = UserDefaults.standard.bool(forKey: "autoPaste")

    private var timer: Timer?
    private var lastChangeCount: Int = NSPasteboard.general.changeCount

    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    func stop() { timer?.invalidate(); timer = nil }

    private func poll() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount

        if let str = pb.string(forType: .string), !str.isEmpty {
            appendText(str)
            return
        }
        if let data = pb.data(forType: .tiff), let img = NSImage(data: data) {
            appendImage(img)
            return
        }
    }

    private func appendText(_ str: String) {
        let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
        if let first = items.first, first.kind == .text, first.text == trimmed { return }
        let item = ClipItem(kind: .text, text: trimmed)
        prepend(item)
    }

    private func appendImage(_ img: NSImage) {
        if let first = items.first, first.kind == .image, let fi = first.image,
           fi.tiffRepresentation == img.tiffRepresentation { return }
        let item = ClipItem(kind: .image, image: img)
        prepend(item)
    }

    private func prepend(_ item: ClipItem) {
        items.insert(item, at: 0)
        if items.count > maxItems { items.removeLast(items.count - maxItems) }
        persist()
    }

    func clear() {
        items.removeAll()
        persist()
    }

    func setMax(_ n: Int) {
        maxItems = max(5, min(500, n))
        UserDefaults.standard.set(maxItems, forKey: "maxItems")
        if items.count > maxItems { items.removeLast(items.count - maxItems) }
    }

    func setAutoPaste(_ on: Bool) {
        autoPaste = on
        UserDefaults.standard.set(on, forKey: "autoPaste")
    }

    private func persist() {
        let texts = items.prefix(100).compactMap { $0.text }
        UserDefaults.standard.set(texts, forKey: "history.texts")
    }

    func loadPersisted() {
        let texts = (UserDefaults.standard.array(forKey: "history.texts") as? [String]) ?? []
        items = texts.map { ClipItem(kind: .text, text: $0) }
    }
}

// MARK: - Status Item + Popover Controller

final class StatusItemController: NSObject {
    static let shared = StatusItemController()

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private var eventMonitor: Any?

    override init() {
        super.init()
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "clipboard", accessibilityDescription: "Clipboard History")
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 420, height: 520)
    }

    func setRootView(_ view: some View) {
        popover.contentViewController = NSHostingController(rootView: AnyView(view))
    }

    @objc func togglePopover(_ sender: Any?) {
        if popover.isShown {
            closePopover(sender)
        } else {
            showPopover(sender)
        }
    }

    func showPopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        startEventMonitor()
    }

    func closePopover(_ sender: Any?) {
        popover.performClose(sender)
        stopEventMonitor()
    }

    private func startEventMonitor() {
        guard eventMonitor == nil else { return }
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePopover(nil)
        }
    }

    private func stopEventMonitor() {
        if let monitor = eventMonitor { NSEvent.removeMonitor(monitor) }
        eventMonitor = nil
    }
}

// MARK: - Global Hotkey (⌘⇧V)

final class HotKeyManager {
    private var hotKeyRef: EventHotKeyRef? = nil
    private var eventHandler: EventHandlerRef? = nil

    func registerDefaultHotKey() {
        register(keyCode: kVK_ANSI_V, mods: cmdKey | shiftKey)
    }

    func register(keyCode: Int, mods: Int) {
        unregister()

        var hotKeyID = EventHotKeyID(signature: OSType("CHV1".fourCharCodeValue), id: 1)
        let eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        InstallEventHandler(GetApplicationEventTarget(), { (next, event, userData) -> OSStatus in
            var hkCom = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hkCom)
            if hkCom.signature == OSType("CHV1".fourCharCodeValue) {
                DispatchQueue.main.async {
                    StatusItemController.shared.togglePopover(nil)
                }
            }
            return noErr
        }, 1, [eventSpec], nil, &eventHandler)

        RegisterEventHotKey(UInt32(keyCode), UInt32(mods), hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    func unregister() {
        if let hk = hotKeyRef { UnregisterEventHotKey(hk); hotKeyRef = nil }
        if let eh = eventHandler { RemoveEventHandler(eh); eventHandler = nil }
    }

    deinit { unregister() }
}

private extension String { var fourCharCodeValue: FourCharCode { return self.utf16.reduce(0) { ($0 << 8) + FourCharCode($1) } } }

// MARK: - Pasteboard Helpers

func copyToPasteboard(_ item: ClipItem) {
    let pb = NSPasteboard.general
    pb.clearContents()
    switch item.kind {
    case .text:
        pb.setString(item.text ?? "", forType: .string)
    case .image:
        if let tiff = item.image?.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            pb.setData(png, forType: .png)
        }
    }
}

func performAutoPaste() {
    let src = CGEventSource(stateID: .combinedSessionState)
    let cmdDown = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(kVK_Command), keyDown: true)
    let vDown = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
    let vUp   = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
    let cmdUp = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(kVK_Command), keyDown: false)
    vDown?.flags = .maskCommand
    vUp?.flags = .maskCommand
    let loc = CGEventTapLocation.cghidEventTap
    cmdDown?.post(tap: loc)
    vDown?.post(tap: loc)
    vUp?.post(tap: loc)
    cmdUp?.post(tap: loc)
}

// MARK: - UI

struct ContentView: View {
    @EnvironmentObject var history: ClipboardHistory
    @State private var query: String = ""

    var filtered: [ClipItem] {
        guard !query.isEmpty else { return history.items }
        let q = query.lowercased()
        return history.items.filter { item in
            switch item.kind {
            case .text: return item.text?.lowercased().contains(q) == true
            case .image: return "image".contains(q)
            }
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                TextField("Search…", text: $query)
                    .textFieldStyle(PlainTextFieldStyle())
            }
            .padding(10)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding([.top, .horizontal])

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(filtered) { item in
                        Button(action: { select(item) }) {
                            HStack(alignment: .center, spacing: 10) {
                                if item.kind == .image, let img = item.image {
                                    Image(nsImage: img)
                                        .resizable()
                                        .interpolation(.high)
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 44, height: 44)
                                        .cornerRadius(8)
                                } else {
                                    Image(systemName: "doc.on.doc")
                                        .frame(width: 44, height: 44)
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.displayTitle)
                                        .font(.system(size: 13))
                                        .lineLimit(2)
                                    Text(item.timestamp.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption2).foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding(8)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }

            Divider()

            HStack {
                Toggle("Auto-Paste", isOn: Binding(get: { history.autoPaste }, set: { history.setAutoPaste($0) }))
                Spacer()
                Stepper(value: Binding(get: { history.maxItems }, set: { history.setMax($0) }), in: 5...500) {
                    Text("Keep: \(history.maxItems)")
                }
                Button(role: .destructive) { history.clear() } label: { Text("Clear") }

                // New gear icon to open Settings
                Button {
                    NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                } label: {
                    Image(systemName: "gearshape")
                }
            }
            .padding([.horizontal, .bottom])
        }
        .frame(minWidth: 380, minHeight: 420)
    }

    private func select(_ item: ClipItem) {
        copyToPasteboard(item)
        StatusItemController.shared.closePopover(nil)
        if history.autoPaste { performAutoPaste() }
    }
}

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

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let hotKey = HotKeyManager()
    let history = ClipboardHistory()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        history.loadPersisted()
        history.start()

        // Wire the popover content
        let root = ContentView().environmentObject(history)
        StatusItemController.shared.setRootView(root)

        // Register ⌘⇧V
        hotKey.registerDefaultHotKey()
    }

    func applicationWillTerminate(_ notification: Notification) {
        history.stop()
    }
}
