
import SwiftUI

// MARK: - Models

struct ClipItem: Identifiable, Equatable, Hashable, Codable {
    enum Kind: String, Codable { case text, image }
    var id = UUID()
    let kind: Kind
    var text: String? = nil
    var image: NSImage? = nil
    var imageHash: Int = 0
    var timestamp: Date = .init()
    var isPinned: Bool = false

    var displayTitle: String {
        switch kind {
        case .text:
            let t = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "(empty)"
            return t.isEmpty ? "(empty)" : t.replacingOccurrences(of: "\n", with: " ⏎ ")
        case .image:
            return "Image \(image?.size.width ?? 0)x\(image?.size.height ?? 0)"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, kind, text, image, imageHash, timestamp, isPinned
    }

    init(kind: Kind, text: String? = nil, image: NSImage? = nil, imageHash: Int = 0) {
        self.kind = kind
        self.text = text
        self.image = image
        self.imageHash = imageHash
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        kind = try container.decode(Kind.self, forKey: .kind)
        text = try container.decodeIfPresent(String.self, forKey: .text)
        if let imageData = try container.decodeIfPresent(Data.self, forKey: .image) {
            image = NSImage(data: imageData)
            imageHash = try container.decodeIfPresent(Int.self, forKey: .imageHash) ?? imageData.hashValue
        } else {
            image = nil
            imageHash = 0
        }
        timestamp = try container.decodeIfPresent(Date.self, forKey: .timestamp) ?? Date()
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(kind, forKey: .kind)
        try container.encodeIfPresent(text, forKey: .text)
        if let image = image, let tiff = image.tiffRepresentation {
            try container.encode(tiff, forKey: .image)
            try container.encode(imageHash, forKey: .imageHash)
        } else {
            try container.encodeNil(forKey: .image)
            try container.encode(0, forKey: .imageHash)
        }
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(isPinned, forKey: .isPinned)
    }
}
