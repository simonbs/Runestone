import UIKit

final class UITextInputClientNavigationHandler<LineManagerType: LineManaging> {
    typealias State = SelectedRangeReadable & SelectedRangeWritable & TextContainerInsetReadable

    var beginningOfDocument: UITextPosition {
        RunestoneUITextPosition(0)
    }
    var endOfDocument: UITextPosition {
        RunestoneUITextPosition(stringView.length)
    }
    var selectedTextRange: UITextRange? {
        get {
            RunestoneUITextRange(state.selectedRange)
        }
        set {
            // We should not use this setter. It's intended for UIKit to use. It'll invoke the setter
            // in various scenarios, for example when navigating the text using the keyboard.
            // On the iOS 16 beta, UIKit may pass an NSRange with a negatives length,
            // e.g. {4, -2}) when double tapping to select text. This will cause a crash when UIKit
            // later attempts to use the selected range with NSString's -substringWithRange:.
            // This can be tested with a string containing the following three lines:
            //    A
            //
            //    A
            // Placing the character on the second line, which is empty, and double tapping several
            // tiems on the empty line to select text will cause the editor to crash. To work around this
            // we take the non-negative value of the selected range. Last tested on August 30th, 2022.
            guard let newUITextRange = newValue as? RunestoneUITextRange else {
                fatalError("Expected a value of type \(type(of: RunestoneUITextRange.self))")
            }
            let newRange = newUITextRange.range.nonNegativeLength
            guard newRange != state.selectedRange else {
                return
            }
//            textEditState.notifyDelegateAboutSelectionChangeInLayoutSubviews = true
            // The logic for determining whether or not to notify the input delegate is based on
            // advice provided by Alexander Blach, developer of Textastic.
            var shouldNotifyInputDelegate = false
            if didCallPositionFromPositionWithOffset {
                shouldNotifyInputDelegate = true
                didCallPositionFromPositionWithOffset = false
            }
//            textEditState.notifyInputDelegateAboutSelectionChangeInLayoutSubviews = !shouldNotifyInputDelegate
            if shouldNotifyInputDelegate {
                selectionEventHandler.selectionWillChange()
            }
            state.selectedRange = newRange
            if shouldNotifyInputDelegate {
                selectionEventHandler.selectionDidChange()
            }
        }
    }
    
    private let state: State
    private let stringView: StringView
    private let lineManager: LineManagerType
    private let navigationLocationProvider: TextNavigationLocationProviding
    private let selectionEventHandler: SelectionEventHandling
    private var didCallPositionFromPositionWithOffset = false

    init(
        state: State,
        stringView: StringView,
        lineManager: LineManagerType,
        navigationLocationProvider: TextNavigationLocationProviding,
        selectionEventHandler: SelectionEventHandling
    ) {
        self.state = state
        self.stringView = stringView
        self.lineManager = lineManager
        self.navigationLocationProvider = navigationLocationProvider
        self.selectionEventHandler = selectionEventHandler
    }

    func textRange(from fromPosition: UITextPosition, to toPosition: UITextPosition) -> UITextRange? {
        guard let fromPosition = fromPosition as? RunestoneUITextPosition,
              let toPosition = toPosition as? RunestoneUITextPosition
        else {
            return nil
        }
        let length = toPosition.location - fromPosition.location
        let range = NSRange(location: fromPosition.location, length: length)
        return RunestoneUITextRange(range)
    }

    func position(from position: UITextPosition, offset: Int) -> UITextPosition? {
        guard let position = position as? RunestoneUITextPosition else {
            return nil
        }
        let newPosition = position.location + offset
        guard newPosition >= 0 && newPosition <= stringView.length else {
            return nil
        }
        didCallPositionFromPositionWithOffset = true
        return RunestoneUITextPosition(newPosition)
    }

    func position(
        from position: UITextPosition,
        in direction: UITextLayoutDirection,
        offset: Int
    ) -> UITextPosition? {
        guard let position = position as? RunestoneUITextPosition else {
            return nil
        }
        guard let direction = TextNavigationDirection(direction) else {
            return nil
        }
        guard let destinationLocation = navigationLocationProvider.location(
            from: position.location,
            inDirection: direction,
            offset: offset
        ) else {
            return nil
        }
        return RunestoneUITextPosition(destinationLocation)
    }

    func compare(_ position: UITextPosition, to other: UITextPosition) -> ComparisonResult {
        guard let position = position as? RunestoneUITextPosition,
              let otherPosition = other as? RunestoneUITextPosition
        else {
            #if targetEnvironment(macCatalyst)
            // Mac Catalyst may pass <uninitialized> to `position`. I'm not sure what the
            // right way to deal with that is but returning .orderedSame seems to work.
            return .orderedSame
            #else
            fatalError("Positions must be of type \(RunestoneUITextPosition.self)")
            #endif
        }
        if position.location < otherPosition.location {
            return .orderedAscending
        } else if position.location > otherPosition.location {
            return .orderedDescending
        } else {
            return .orderedSame
        }
    }

    func offset(from: UITextPosition, to toPosition: UITextPosition) -> Int {
        guard let fromPosition = from as? RunestoneUITextPosition,
              let toPosition = toPosition as? RunestoneUITextPosition 
        else {
            return 0
        }
        return toPosition.location - fromPosition.location
    }

    func position(within range: UITextRange, farthestIn direction: UITextLayoutDirection) -> UITextPosition? {
        // This implementation seems to match the behavior of UITextView.
        guard let range = range as? RunestoneUITextRange else {
            return nil
        }
        switch direction {
        case .left, .up:
            return RunestoneUITextPosition(range.range.lowerBound)
        case .right, .down:
            return RunestoneUITextPosition(range.range.upperBound)
        @unknown default:
            return nil
        }
    }

    func characterRange(
        byExtending position: UITextPosition,
        in direction: UITextLayoutDirection
    ) -> UITextRange? {
        // This implementation seems to match the behavior of UITextView.
        guard let position = position as? RunestoneUITextPosition else {
            return nil
        }
        switch direction {
        case .left, .up:
            let leftLocation = max(position.location - 1, 0)
            return RunestoneUITextRange(location: leftLocation, length: position.location - leftLocation)
        case .right, .down:
            let rightLocation = min(position.location + 1, stringView.length)
            return RunestoneUITextRange(location: position.location, length: rightLocation - position.location)
        @unknown default:
            return nil
        }
    }

    func closestPosition(to point: CGPoint) -> UITextPosition? {
        let insetPoint = CGPoint(x: point.x - state.textContainerInset.left, y: point.y - state.textContainerInset.top)
        if let line = lineManager.line(atYOffset: insetPoint.y) {
            let lineLocalPoint = CGPoint(x: insetPoint.x, y: insetPoint.y - line.yPosition)
            let location = line.location(closestTo: lineLocalPoint)
            return RunestoneUITextPosition(location)
        } else if point.y <= 0 {
            return RunestoneUITextPosition(0)
        } else {
            return RunestoneUITextPosition(stringView.length)
        }
    }

    func closestPosition(to point: CGPoint, within range: UITextRange) -> UITextPosition? {
        guard let range = range as? RunestoneUITextRange else {
            return nil
        }
        guard let position = closestPosition(to: point) as? RunestoneUITextPosition else {
            return nil
        }
        let cappedLocation = min(max(position.location, range.range.lowerBound), range.range.upperBound)
        return RunestoneUITextPosition(cappedLocation)
    }

    func characterRange(at point: CGPoint) -> UITextRange? {
        guard let position = closestPosition(to: point) as? RunestoneUITextPosition else {
            return nil
        }
        let cappedLocation = max(position.location - 1, 0)
        let range = stringView.string.customRangeOfComposedCharacterSequence(at: cappedLocation)
        return RunestoneUITextRange(range)
    }
}

private extension TextNavigationDirection {
    init?(_ direction: UITextLayoutDirection) {
        switch direction {
        case .right:
            self = .right
        case .left:
            self = .left
        case .up:
            self = .up
        case .down:
            self = .down
        @unknown default:
            return nil
        }
    }
}
