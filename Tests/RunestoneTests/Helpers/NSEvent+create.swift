#if os(macOS)
import AppKit
import Carbon


extension NSEvent {
    /// Creates an event which can be used in tests.
    /// It simulates a key down event for the given ASCII character.
    static func create(characters: String, modifiers: NSEvent.ModifierFlags) throws -> NSEvent {
        guard let keyCode = keyMapping[characters] else { throw SetupError.unknownCharacters(characters) }

        guard let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: CFTimeInterval(), windowNumber: 0, context: nil, characters: "", charactersIgnoringModifiers: characters, isARepeat: false, keyCode: keyCode) else {
            throw SetupError.eventCreationError
        }

        return event
    }

    /// Creates an event which can be used in tests.
    /// It simulates a key down event for the given device-independent key.
    static func create(key: KeyboardIndependentKeys, modifiers: NSEvent.ModifierFlags = []) throws -> NSEvent {
        let keyCode = CGKeyCode(UInt16(key.keyCode))
        guard
            let cgEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
            let nsEvent = NSEvent(cgEvent: cgEvent)
        else { throw SetupError.eventCreationError }

        guard let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: CFTimeInterval(), windowNumber: 0, context: nil, characters: nsEvent.characters ?? "", charactersIgnoringModifiers: nsEvent.charactersIgnoringModifiers ?? "", isARepeat: false, keyCode: keyCode) else {
            throw SetupError.eventCreationError
        }

        return event
    }
}


/// A mapping where the mapping's key is an ASCII character and the value is the key code for the character based on current keyboard.
/// This is used to translate keyboard-dependent characters into the correct keyboard.
private let keyMapping: [String: UInt16] = {
    var mapping: [String: UInt16] = [:]
    for keyCode in (0..<128) {
        guard let cgevent = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(keyCode), keyDown: true) else { continue }
        guard let nsevent = NSEvent(cgEvent: cgevent) else { continue }

        guard nsevent.type == .keyDown, nsevent.specialKey == nil, let characters = nsevent.charactersIgnoringModifiers, !characters.isEmpty else { continue }
        mapping[characters] = UInt16(keyCode)
    }

    return mapping
}()


/// All keys which are independent from the keyboard, so they have the same key code on all keyboards.
enum KeyboardIndependentKeys {
    case `return`
    case tab
    case space
    case delete
    case escape
    case command
    case shift
    case capsLock
    case option
    case control
    case rightCommand
    case rightShift
    case rightOption
    case rightControl
    case function
    case volumeUp
    case volumeDown
    case mute
    case f1
    case f2
    case f3
    case f4
    case f5
    case f6
    case f7
    case f8
    case f9
    case f10
    case f11
    case f12
    case f13
    case f14
    case f15
    case f16
    case f17
    case f18
    case f19
    case f20
    case help
    case home
    case pageUp
    case forwardDelete
    case end
    case pageDown
    case leftArrow
    case rightArrow
    case downArrow
    case upArrow

    var keyCode: Int {
        switch self {
        case .`return`: return kVK_Return
        case .tab: return kVK_Tab
        case .space: return kVK_Space
        case .delete: return kVK_Delete
        case .escape: return kVK_Escape
        case .command: return kVK_Command
        case .shift: return kVK_Shift
        case .capsLock: return kVK_CapsLock
        case .option: return kVK_Option
        case .control: return kVK_Control
        case .rightCommand: return kVK_RightCommand
        case .rightShift: return kVK_RightShift
        case .rightOption: return kVK_RightOption
        case .rightControl: return kVK_RightControl
        case .function: return kVK_Function
        case .volumeUp: return kVK_VolumeUp
        case .volumeDown: return kVK_VolumeDown
        case .mute: return kVK_Mute
        case .f1: return kVK_F1
        case .f2: return kVK_F2
        case .f3: return kVK_F3
        case .f4: return kVK_F4
        case .f5: return kVK_F5
        case .f6: return kVK_F6
        case .f7: return kVK_F7
        case .f8: return kVK_F8
        case .f9: return kVK_F9
        case .f10: return kVK_F10
        case .f11: return kVK_F11
        case .f12: return kVK_F12
        case .f13: return kVK_F13
        case .f14: return kVK_F14
        case .f15: return kVK_F15
        case .f16: return kVK_F16
        case .f17: return kVK_F17
        case .f18: return kVK_F18
        case .f19: return kVK_F19
        case .f20: return kVK_F20
        case .help: return kVK_Help
        case .home: return kVK_Home
        case .pageUp: return kVK_PageUp
        case .forwardDelete: return kVK_ForwardDelete
        case .end: return kVK_End
        case .pageDown: return kVK_PageDown
        case .leftArrow: return kVK_LeftArrow
        case .rightArrow: return kVK_RightArrow
        case .downArrow: return kVK_DownArrow
        case .upArrow: return kVK_UpArrow
        }
    }
}

enum SetupError: Error {
    case unknownCharacters(String)
    case eventCreationError
}

#endif
