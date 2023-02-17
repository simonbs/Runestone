#if os(macOS)
import AppKit
import Carbon

private enum NSEventError: LocalizedError {
    case unknownCharacters(String)
    case failedCreatingEvent

    var errorDescription: String? {
        switch self {
        case .unknownCharacters(let string):
            return "Unknown characters '\(string)'"
        case .failedCreatingEvent:
            return "Failed creating event"
        }
    }
}

extension NSEvent {
    /// Creates an event which can be used in tests.
    ///
    /// Simulates a key down event for the given ASCII character.
    static func keyEvent(pressing characters: String, withModifiers modifiers: NSEvent.ModifierFlags) throws -> NSEvent {
        guard let keyCode = keyMapping[characters] else {
            throw NSEventError.unknownCharacters(characters)
        }
        guard let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: CFTimeInterval(),
            windowNumber: 0,
            context: nil,
            characters: "",
            charactersIgnoringModifiers: characters,
            isARepeat: false,
            keyCode: keyCode
        ) else {
            throw NSEventError.failedCreatingEvent
        }
        return event
    }

    /// Creates an event which can be used in tests.
    ///
    /// Simulates a key down event for the given device-independent key.
    static func keyEvent(pressing key: NSEvent.Key, withModifiers modifiers: NSEvent.ModifierFlags = []) throws -> NSEvent {
        let keyCode = CGKeyCode(UInt16(key.code))
        guard let cgEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
              let nsEvent = NSEvent(cgEvent: cgEvent) else {
            throw NSEventError.failedCreatingEvent
        }
        guard let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: CFTimeInterval(),
            windowNumber: 0,
            context: nil,
            characters: nsEvent.characters ?? "",
            charactersIgnoringModifiers: nsEvent.charactersIgnoringModifiers ?? "",
            isARepeat: false,
            keyCode: keyCode
        ) else {
            throw NSEventError.failedCreatingEvent
        }
        return event
    }
}

extension NSEvent {
    enum Key {
        case leftArrow
        case upArrow
        case rightArrow
        case downArrow

        var code: Int {
            switch self {
            case .leftArrow:
                return kVK_LeftArrow
            case .upArrow:
                return kVK_UpArrow
            case .rightArrow:
                return kVK_RightArrow
            case .downArrow:
                return kVK_DownArrow
            }
        }
    }
}

private extension NSEvent {
    /// A mapping where the mapping's key is an ASCII character and the value is the key code for the character based on current keyboard.
    /// This is used to translate keyboard-dependent characters into the correct keyboard.
    private static var keyMapping: [String: UInt16] {
        var mapping: [String: UInt16] = [:]
        for keyCode in (0 ..< 128) {
            guard let cgevent = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(keyCode), keyDown: true) else {
                continue
            }
            guard let nsevent = NSEvent(cgEvent: cgevent) else {
                continue
            }
            guard nsevent.type == .keyDown, nsevent.specialKey == nil,
                  let characters = nsevent.charactersIgnoringModifiers,
                  !characters.isEmpty else {
                continue
            }
            mapping[characters] = UInt16(keyCode)
        }
        return mapping
    }
}
#endif
