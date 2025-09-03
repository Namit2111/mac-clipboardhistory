
import SwiftUI
import Combine

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
