import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var hotKeyManager: HotKeyManager
    @EnvironmentObject var history: ClipboardHistory
    @Environment(\.dismiss) var dismiss
    @State private var showingHotKeyRecorder = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding()
            
            Divider()
            
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Global Hotkey")
                        .font(.headline)
                    
                    HStack {
                        Text("Current hotkey:")
                            .foregroundColor(.secondary)
                        
                        Text(hotKeyManager.hotKey.isEmpty ? "Not set" : hotKeyManager.hotKey)
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.medium)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(6)
                        
                        Spacer()
                        
                        Button("Change") {
                            showingHotKeyRecorder = true
                        }
                        
                        if !hotKeyManager.hotKey.isEmpty {
                            Button("Clear") {
                                hotKeyManager.unregister()
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.red)
                        }
                    }
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Behavior")
                        .font(.headline)
                    
                    Toggle(isOn: Binding(
                        get: { history.autoPaste },
                        set: { history.setAutoPaste($0) }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Auto-paste after selection")
                            Text("Automatically paste the selected item")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Storage")
                        .font(.headline)
                    
                    HStack {
                        Text("Maximum items:")
                            .foregroundColor(.secondary)
                        
                        Stepper(value: Binding(
                            get: { history.maxItems },
                            set: { history.setMax($0) }
                        ), in: 5...500, step: 10) {
                            Text("\(history.maxItems) items")
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.medium)
                        }
                    }
                    
                    Text("Currently storing \(history.items.count) items")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
        }
        .frame(width: 450, height: 380)
        .sheet(isPresented: $showingHotKeyRecorder) {
            HotKeyRecorderView(isPresented: $showingHotKeyRecorder)
                .environmentObject(hotKeyManager)
        }
    }
}