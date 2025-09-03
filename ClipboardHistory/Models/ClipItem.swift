
import SwiftUI

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
