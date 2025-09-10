
import SwiftUI

// MARK: - Status Item + Popover Controller

final class StatusItemController: NSObject, NSPopoverDelegate {
    static let shared = StatusItemController()

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private var eventMonitor: Any?
    private var localMonitor: Any?
    private var anchorWindow: NSWindow?

    override init() {
        super.init()
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "clipboard", accessibilityDescription: "Clipboard History")
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 400, height: 500)
        popover.animates = true
        popover.delegate = self
    }

    func setRootView(_ view: some View) {
        popover.contentViewController = NSHostingController(rootView: AnyView(view))
    }

    @objc func togglePopover(_ sender: Any?) {
        if popover.isShown {
            closePopover(sender)
        } else {
            showPopover(sender)
        }
    }

    func showPopover(_ sender: Any?) {
        if sender != nil {
            // Clicked from status bar - show from button
            guard let button = statusItem.button else { return }
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        } else {
            // Triggered via hotkey - show at mouse cursor
            showPopoverAtCursor()
        }
        
        NSApp.activate(ignoringOtherApps: true)
        
        if let window = popover.contentViewController?.view.window {
            window.makeKey()
            window.makeFirstResponder(popover.contentViewController?.view)
        }
        
        startEventMonitor()
    }
    
    private func showPopoverAtCursor() {
        // Clean up any existing anchor window first
        cleanupAnchorWindow()
        
        let mouseLocation = NSEvent.mouseLocation
        let screenFrame = NSScreen.main?.frame ?? .zero
        
        // Create a tiny invisible anchor window at cursor position
        let anchorFrame = NSRect(x: mouseLocation.x, y: screenFrame.height - mouseLocation.y, width: 1, height: 1)
        
        let window = NSWindow(
            contentRect: anchorFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        
        let anchorView = NSView(frame: NSRect(x: 0, y: 0, width: 1, height: 1))
        window.contentView = anchorView
        
        // Store reference before showing
        anchorWindow = window
        window.makeKeyAndOrderFront(nil)
        
        // Determine preferred edge based on cursor position
        let preferredEdge: NSRectEdge
        if mouseLocation.y > screenFrame.height / 2 {
            preferredEdge = .minY  // Show below cursor if in top half
        } else {
            preferredEdge = .maxY  // Show above cursor if in bottom half
        }
        
        popover.show(relativeTo: anchorView.bounds, of: anchorView, preferredEdge: preferredEdge)
    }

    func closePopover(_ sender: Any?) {
        popover.performClose(sender)
        stopEventMonitor()
        cleanupAnchorWindow()
    }
    
    private func cleanupAnchorWindow() {
        if let window = anchorWindow {
            window.orderOut(nil)
            window.close()
        }
        anchorWindow = nil
    }

    private func startEventMonitor() {
        stopEventMonitor()
        
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if let strongSelf = self, strongSelf.popover.isShown {
                strongSelf.closePopover(nil)
            }
        }
        
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.closePopover(nil)
                return nil
            }
            return event
        }
    }

    private func stopEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }
    
    func popoverWillShow(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func popoverDidClose(_ notification: Notification) {
        stopEventMonitor()
        cleanupAnchorWindow()
    }
}
