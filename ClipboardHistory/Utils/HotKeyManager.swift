import Foundation
import Carbon.HIToolbox
import SwiftUI

final class HotKeyManager: ObservableObject {
    @Published var hotKey: String = ""
    @Published var currentKeyCode: Int = 0
    @Published var currentModifiers: Int = 0
    
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private static var sharedManager: HotKeyManager?
    
    init() {
        HotKeyManager.sharedManager = self
        loadSavedHotKey()
    }
    
    deinit {
        unregister()
    }
    
    func registerDefaultHotKey() {
        if currentKeyCode == 0 {
            register(keyCode: kVK_ANSI_V, mods: cmdKey | shiftKey)
        } else {
            register(keyCode: currentKeyCode, mods: currentModifiers)
        }
    }
    
    func register(keyCode: Int, mods: Int) {
        unregister()
        
        currentKeyCode = keyCode
        currentModifiers = mods
        saveHotKey()
        
        let hotKeyID = EventHotKeyID(
            signature: OSType("CHV1".fourCharCodeValue),
            id: UInt32(1)
        )
        
        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        
        let handler: EventHandlerUPP = { (nextHandler, event, userData) -> OSStatus in
            var hkCom = EventHotKeyID()
            GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hkCom
            )
            
            if hkCom.signature == OSType("CHV1".fourCharCodeValue) && hkCom.id == 1 {
                DispatchQueue.main.async {
                    StatusItemController.shared.togglePopover(nil)
                }
            }
            return noErr
        }
        
        InstallEventHandler(
            GetApplicationEventTarget(),
            handler,
            1,
            &eventSpec,
            nil,
            &eventHandler
        )
        
        RegisterEventHotKey(
            UInt32(keyCode),
            UInt32(mods),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        
        hotKey = keyCodeToString(keyCode: keyCode, mods: mods)
    }
    
    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
        hotKey = ""
        currentKeyCode = 0
        currentModifiers = 0
        saveHotKey()
    }
    
    func keyCodeToString(keyCode: Int, mods: Int) -> String {
        var str = ""
        if (mods & cmdKey) != 0 { str += "⌘" }
        if (mods & optionKey) != 0 { str += "⌥" }
        if (mods & controlKey) != 0 { str += "⌃" }
        if (mods & shiftKey) != 0 { str += "⇧" }
        
        let keyMap: [Int: String] = [
            kVK_ANSI_A: "A", kVK_ANSI_B: "B", kVK_ANSI_C: "C", kVK_ANSI_D: "D",
            kVK_ANSI_E: "E", kVK_ANSI_F: "F", kVK_ANSI_G: "G", kVK_ANSI_H: "H",
            kVK_ANSI_I: "I", kVK_ANSI_J: "J", kVK_ANSI_K: "K", kVK_ANSI_L: "L",
            kVK_ANSI_M: "M", kVK_ANSI_N: "N", kVK_ANSI_O: "O", kVK_ANSI_P: "P",
            kVK_ANSI_Q: "Q", kVK_ANSI_R: "R", kVK_ANSI_S: "S", kVK_ANSI_T: "T",
            kVK_ANSI_U: "U", kVK_ANSI_V: "V", kVK_ANSI_W: "W", kVK_ANSI_X: "X",
            kVK_ANSI_Y: "Y", kVK_ANSI_Z: "Z",
            kVK_ANSI_0: "0", kVK_ANSI_1: "1", kVK_ANSI_2: "2", kVK_ANSI_3: "3",
            kVK_ANSI_4: "4", kVK_ANSI_5: "5", kVK_ANSI_6: "6", kVK_ANSI_7: "7",
            kVK_ANSI_8: "8", kVK_ANSI_9: "9",
            kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫",
            kVK_Escape: "⎋", kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3",
            kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6", kVK_F7: "F7",
            kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11",
            kVK_F12: "F12", kVK_LeftArrow: "←", kVK_RightArrow: "→",
            kVK_UpArrow: "↑", kVK_DownArrow: "↓",
            kVK_ANSI_Minus: "-", kVK_ANSI_Equal: "=", kVK_ANSI_LeftBracket: "[",
            kVK_ANSI_RightBracket: "]", kVK_ANSI_Semicolon: ";",
            kVK_ANSI_Quote: "'", kVK_ANSI_Comma: ",", kVK_ANSI_Period: ".",
            kVK_ANSI_Slash: "/", kVK_ANSI_Backslash: "\\", kVK_ANSI_Grave: "`"
        ]
        
        if let key = keyMap[keyCode] {
            str += key
        } else {
            str += "Key\(keyCode)"
        }
        
        return str
    }
    
    private func saveHotKey() {
        UserDefaults.standard.set(currentKeyCode, forKey: "hotKeyCode")
        UserDefaults.standard.set(currentModifiers, forKey: "hotKeyModifiers")
        UserDefaults.standard.synchronize()
    }
    
    private func loadSavedHotKey() {
        currentKeyCode = UserDefaults.standard.integer(forKey: "hotKeyCode")
        currentModifiers = UserDefaults.standard.integer(forKey: "hotKeyModifiers")
        
        if currentKeyCode != 0 {
            hotKey = keyCodeToString(keyCode: currentKeyCode, mods: currentModifiers)
        }
    }
}

private extension String {
    var fourCharCodeValue: FourCharCode {
        return self.utf16.reduce(0) { ($0 << 8) + FourCharCode($1) }
    }
}