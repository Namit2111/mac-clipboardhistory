import SwiftUI

struct ContentView: View {
    @EnvironmentObject var history: ClipboardHistory
    @EnvironmentObject var hotKeyManager: HotKeyManager
    @State private var query: String = ""
    @State private var showingSettings = false
    @State private var selectedItemID: UUID?
    @State private var copiedItemID: UUID?
    @FocusState private var searchFieldFocused: Bool
    
    var filtered: [ClipItem] {
        guard !query.isEmpty else { return history.items }
        let q = query.lowercased()
        let filteredItems = history.items.filter { item in
            switch item.kind {
            case .text: return item.text?.lowercased().contains(q) == true
            case .image: return "image".contains(q)
            }
        }
        // Ensure pinned items stay at the top even when filtered
        return filteredItems.sorted { lhs, rhs in
            if lhs.isPinned && !rhs.isPinned { return true }
            if !lhs.isPinned && rhs.isPinned { return false }
            return false // Keep original order for same pin status
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search...", text: $query)
                    .textFieldStyle(PlainTextFieldStyle())
                    .focused($searchFieldFocused)
                    .onSubmit {
                        if let first = filtered.first {
                            select(first)
                        }
                    }
                if !query.isEmpty {
                    Button(action: { query = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding()
            
            if filtered.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clipboard")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text(query.isEmpty ? "No items in clipboard history" : "No matching items")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    if !query.isEmpty {
                        Button("Clear search") {
                            query = ""
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(filtered) { item in
                            ClipItemRow(
                                item: item,
                                isSelected: selectedItemID == item.id,
                                isCopied: copiedItemID == item.id,
                                onSelect: { select(item) },
                                onPinToggle: { history.togglePin(for: item.id) },
                                onHover: { hovering in
                                    if hovering {
                                        selectedItemID = item.id
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
            }
            
            Divider()
            
            HStack(spacing: 12) {
                Toggle(isOn: Binding(
                    get: { history.autoPaste },
                    set: { history.setAutoPaste($0) }
                )) {
                    Text("Auto-Paste")
                        .font(.system(size: 11))
                }
                .toggleStyle(.checkbox)
                .controlSize(.small)
                
                Spacer()
                
                Text("\(history.items.count) items")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                Button(action: { showingSettings = true }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                
                if !history.items.isEmpty {
                    Divider()
                        .frame(height: 16)
                    
                    Button(action: { history.clear() }) {
                        Text("Clear All")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.red)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        }
        .frame(width: 400, height: 500)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            searchFieldFocused = true
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(history)
                .environmentObject(hotKeyManager)
        }
    }
    
    private func select(_ item: ClipItem) {
        copyToPasteboard(item)
        
        withAnimation(.easeInOut(duration: 0.2)) {
            copiedItemID = item.id
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            StatusItemController.shared.closePopover(nil)
            
            if history.autoPaste {
                // Wait longer to ensure focus is restored before pasting
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    performAutoPaste()
                }
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            copiedItemID = nil
        }
    }
}

struct ClipItemRow: View {
    let item: ClipItem
    let isSelected: Bool
    let isCopied: Bool
    let onSelect: () -> Void
    let onPinToggle: () -> Void
    let onHover: (Bool) -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .center, spacing: 10) {
                if item.kind == .image, let img = item.image {
                    Image(nsImage: img)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                } else {
                    Image(systemName: "doc.text")
                        .font(.system(size: 20))
                        .frame(width: 40, height: 40)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.displayTitle)
                        .font(.system(size: 13))
                        .lineLimit(2)
                        .truncationMode(.tail)
                    
                    HStack(spacing: 4) {
                        Text(timeAgo(from: item.timestamp))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        
                        if isCopied {
                            Text("Copied!")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.green)
                        }
                    }
                }
                
                Spacer()
                
                Button(action: onPinToggle) {
                    Image(systemName: item.isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 12))
                        .foregroundColor(item.isPinned ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    // Prevent hover state from affecting parent row
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isCopied ? Color.green.opacity(0.5) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            onHover(hovering)
        }
    }
    
    private func timeAgo(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes) min\(minutes == 1 ? "" : "s") ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days) day\(days == 1 ? "" : "s") ago"
        }
    }
}