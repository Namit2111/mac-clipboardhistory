
import AppKit
import Carbon.HIToolbox

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
