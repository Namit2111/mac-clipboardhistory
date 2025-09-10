
import AppKit
import Carbon.HIToolbox

// MARK: - Pasteboard Helpers

func copyToPasteboard(_ item: ClipItem) {
    let pb = NSPasteboard.general
    pb.clearContents()
    
    switch item.kind {
    case .text:
        if let text = item.text, !text.isEmpty {
            let success = pb.setString(text, forType: .string)
            if !success {
                print("Failed to copy text to pasteboard")
            }
        }
    case .image:
        if let image = item.image,
           let tiff = image.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff) {
            
            var types: [NSPasteboard.PasteboardType] = []
            var items: [NSPasteboard.PasteboardType: Data] = [:]
            
            if let png = rep.representation(using: .png, properties: [:]) {
                types.append(.png)
                items[.png] = png
            }
            
            types.append(.tiff)
            items[.tiff] = tiff
            
            pb.declareTypes(types, owner: nil)
            for (type, data) in items {
                pb.setData(data, forType: type)
            }
        }
    }
}

func performAutoPaste() {
    // First try direct paste via responder chain
    if tryDirectPaste() {
        return
    }
    
    // Fallback to simulated keystrokes with longer delays
    guard let src = CGEventSource(stateID: .combinedSessionState) else {
        print("Failed to create event source for auto-paste")
        return
    }
    
    guard let cmdDown = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(kVK_Command), keyDown: true),
          let vDown = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true),
          let vUp = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false),
          let cmdUp = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(kVK_Command), keyDown: false) else {
        print("Failed to create keyboard events for auto-paste")
        return
    }
    
    vDown.flags = .maskCommand
    vUp.flags = .maskCommand
    
    let loc = CGEventTapLocation.cghidEventTap
    
    cmdDown.post(tap: loc)
    Thread.sleep(forTimeInterval: 0.02)
    vDown.post(tap: loc)
    Thread.sleep(forTimeInterval: 0.02)
    vUp.post(tap: loc)
    Thread.sleep(forTimeInterval: 0.02)
    cmdUp.post(tap: loc)
}

private func tryDirectPaste() -> Bool {
    // Try to find the currently active text field and paste directly
    guard let keyWindow = NSApp.keyWindow,
          let firstResponder = keyWindow.firstResponder else {
        return false
    }
    
    // Check if the first responder can handle paste
    let pasteSelector = Selector(("paste:"))
    if firstResponder.responds(to: pasteSelector) {
        firstResponder.perform(pasteSelector, with: nil)
        return true
    }
    
    return false
}
