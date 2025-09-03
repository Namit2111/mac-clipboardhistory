
import Foundation
import Carbon.HIToolbox

// MARK: - Global Hotkey (⌘⇧V)

final class HotKeyManager {
    private var hotKeyRef: EventHotKeyRef? = nil
    private var eventHandler: EventHandlerRef? = nil

    func registerDefaultHotKey() {
        register(keyCode: kVK_ANSI_V, mods: cmdKey | shiftKey)
    }

    func register(keyCode: Int, mods: Int) {
        unregister()

        var hotKeyID = EventHotKeyID(signature: OSType("CHV1".fourCharCodeValue), id: 1)
        let eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        InstallEventHandler(GetApplicationEventTarget(), { (next, event, userData) -> OSStatus in
            var hkCom = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hkCom)
            if hkCom.signature == OSType("CHV1".fourCharCodeValue) {
                DispatchQueue.main.async {
                    StatusItemController.shared.togglePopover(nil)
                }
            }
            return noErr
        }, 1, [eventSpec], nil, &eventHandler)

        RegisterEventHotKey(UInt32(keyCode), UInt32(mods), hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    func unregister() {
        if let hk = hotKeyRef { UnregisterEventHotKey(hk); hotKeyRef = nil }
        if let eh = eventHandler { RemoveEventHandler(eh); eventHandler = nil }
    }

    deinit { unregister() }
}

private extension String { var fourCharCodeValue: FourCharCode { return self.utf16.reduce(0) { ($0 << 8) + FourCharCode($1) } } }
