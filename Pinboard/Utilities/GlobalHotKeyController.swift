//
//  GlobalHotKeyController.swift
//  Pinboard
//

import Carbon.HIToolbox
import Foundation

extension Notification.Name {
    static let pinboardToggleMode = Notification.Name("Pinboard.ToggleMode")
}

private let pinboardHotKeyHandler: EventHandlerUPP = { _, _, _ in
    DispatchQueue.main.async {
        NotificationCenter.default.post(name: .pinboardToggleMode, object: nil)
    }
    return noErr
}

final class GlobalHotKeyController {
    private var hotKeyReference: EventHotKeyRef?
    private var eventHandlerReference: EventHandlerRef?

    private(set) var isRegistered = false

    init() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            pinboardHotKeyHandler,
            1,
            &eventType,
            nil,
            &eventHandlerReference
        )

        guard handlerStatus == noErr else { return }

        let hotKeyID = EventHotKeyID(signature: 0x50494E42, id: 1) // PINB
        let registrationStatus = RegisterEventHotKey(
            UInt32(kVK_Space),
            UInt32(optionKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyReference
        )

        isRegistered = registrationStatus == noErr
    }

    deinit {
        if let hotKeyReference {
            UnregisterEventHotKey(hotKeyReference)
        }
        if let eventHandlerReference {
            RemoveEventHandler(eventHandlerReference)
        }
    }
}

