
import SwiftUI

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
