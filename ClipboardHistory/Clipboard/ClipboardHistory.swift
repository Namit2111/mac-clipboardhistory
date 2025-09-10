
import SwiftUI
import Combine

// MARK: - Clipboard Watcher

final class ClipboardHistory: ObservableObject {
    @Published var items: [ClipItem] = []
    @Published var maxItems: Int = {
        let saved = UserDefaults.standard.integer(forKey: "maxItems")
        return saved > 0 ? saved : 50
    }()
    @Published var autoPaste: Bool = UserDefaults.standard.bool(forKey: "autoPaste")

    private weak var timer: Timer?
    private var lastChangeCount: Int = NSPasteboard.general.changeCount
    private var lastImageHash: Int = 0

    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

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
        guard !trimmed.isEmpty else { return }
        if let first = items.first, first.kind == .text, first.text == trimmed { return }
        
        // Remove any existing duplicate text items
        items.removeAll { item in
            item.kind == .text && item.text == trimmed
        }
        
        let item = ClipItem(kind: .text, text: trimmed)
        prepend(item)
    }

    private func appendImage(_ img: NSImage) {
        let hash = img.tiffRepresentation?.hashValue ?? 0
        if hash == lastImageHash { return }
        lastImageHash = hash
        
        if let first = items.first, first.kind == .image, first.imageHash == hash { return }
        
        // Remove any existing duplicate image items
        items.removeAll { item in
            item.kind == .image && item.imageHash == hash
        }
        
        let item = ClipItem(kind: .image, image: img, imageHash: hash)
        prepend(item)
    }

    private func prepend(_ item: ClipItem) {
        // Find the insertion point - after any pinned items
        let insertionIndex = items.firstIndex { !$0.isPinned } ?? items.count
        items.insert(item, at: insertionIndex)
        if items.count > maxItems { items.removeLast(items.count - maxItems) }
        persist()
    }

    func clear() {
        items.removeAll()
        persist()
    }
    
    func togglePin(for itemID: UUID) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        
        items[index].isPinned.toggle()
        
        // If item was pinned, move it to the top (among pinned items)
        // If item was unpinned, move it to the first unpinned position
        let item = items.remove(at: index)
        
        if item.isPinned {
            // Find the last pinned item and insert after it
            let pinnedCount = items.filter { $0.isPinned }.count
            items.insert(item, at: pinnedCount)
        } else {
            // Find the first unpinned item and insert there
            let insertionIndex = items.firstIndex { !$0.isPinned } ?? items.count
            items.insert(item, at: insertionIndex)
        }
        
        persist()
    }

    func setMax(_ n: Int) {
        maxItems = max(5, min(500, n))
        UserDefaults.standard.set(maxItems, forKey: "maxItems")
        UserDefaults.standard.synchronize()
        if items.count > maxItems {
            items.removeLast(items.count - maxItems)
            persist()
        }
    }

    func setAutoPaste(_ on: Bool) {
        autoPaste = on
        UserDefaults.standard.set(on, forKey: "autoPaste")
        UserDefaults.standard.synchronize()
    }

    private func persist() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(items)
            UserDefaults.standard.set(data, forKey: "history")
            UserDefaults.standard.synchronize()
        } catch {
            print("Failed to persist clipboard history: \(error)")
        }
    }

    func loadPersisted() {
        guard let data = UserDefaults.standard.data(forKey: "history") else { return }
        do {
            let decoder = JSONDecoder()
            items = try decoder.decode([ClipItem].self, from: data)
        } catch {
            print("Failed to load persisted clipboard history: \(error)")
            items = []
        }
    }
}
