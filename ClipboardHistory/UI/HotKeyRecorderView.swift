import SwiftUI
import Carbon.HIToolbox

struct HotKeyRecorderView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var hotKeyManager: HotKeyManager
    @State private var recordedKey: String = "Press keys..."
    @State private var eventMonitor: Any?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Set Global Hotkey")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(recordedKey)
                .font(.system(size: 24, weight: .medium, design: .monospaced))
                .frame(minWidth: 200, minHeight: 60)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor, lineWidth: 2)
                )
            
            Text("Press a key combination with modifiers\n(⌘, ⌥, ⌃, ⇧)")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 20) {
                Button("Cancel") {
                    cleanup()
                    isPresented = false
                }
                .keyboardShortcut(.escape, modifiers: [])
                
                Button("Clear") {
                    hotKeyManager.unregister()
                    recordedKey = "Hotkey cleared"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        cleanup()
                        isPresented = false
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(30)
        .frame(width: 400, height: 250)
        .onAppear {
            recordedKey = "Press keys..."
            startMonitoring()
        }
        .onDisappear {
            cleanup()
        }
    }
    
    private func startMonitoring() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handleKeyEvent(event)
            return nil
        }
    }
    
    private func cleanup() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    
    private func handleKeyEvent(_ event: NSEvent) {
        let keyCode = Int(event.keyCode)
        
        if keyCode == 53 {
            cleanup()
            isPresented = false
            return
        }
        
        let mods = event.modifierFlags
        
        guard mods.contains(.command) || mods.contains(.option) || 
              mods.contains(.control) || mods.contains(.shift) else {
            recordedKey = "Need modifier keys!"
            return
        }
        
        let carbonMods = mods.carbonFlags
        let keyString = hotKeyManager.keyCodeToString(keyCode: keyCode, mods: carbonMods)
        recordedKey = keyString
        
        hotKeyManager.register(keyCode: keyCode, mods: carbonMods)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            cleanup()
            isPresented = false
        }
    }
}

extension NSEvent.ModifierFlags {
    var carbonFlags: Int {
        var flags = 0
        if contains(.command) { flags |= cmdKey }
        if contains(.option) { flags |= optionKey }
        if contains(.control) { flags |= controlKey }
        if contains(.shift) { flags |= shiftKey }
        return flags
    }
}