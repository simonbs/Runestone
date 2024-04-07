import _RunestoneObservation
import Foundation

@RunestoneObserver
final class ThemedStringView<
    StringViewType: StringView,
    State: KernReadable & ThemeReadable
>: StringView {
    var string: String {
        get {
            stringView.string
        }
        set {
            stringView.string = newValue
            reapplyDefaultAttributes()
        }
    }

    var attributedString: NSAttributedString {
        stringView.attributedString
    }
    
    private let stringView: StringViewType
    private let state: State
    private var defaultAttributes: [NSAttributedString.Key: Any] {
        [
            .font: state.theme.font,
            .foregroundColor: state.theme.textColor,
            .kern: state.kern as NSNumber
        ]
    }

    init(stringView: StringViewType, state: State) {
        self.stringView = stringView
        self.state = state
        observe(state.theme) { [weak self] _, _ in
            self?.reapplyDefaultAttributes()
        }
        observe(state.kern) { [weak self] _, _ in
            self?.reapplyDefaultAttributes()
        }
    }

    func attributedSubstring(in range: NSRange) -> NSAttributedString? {
        stringView.attributedSubstring(in: range)
    }

    func setAttributes(_ attributes: [NSAttributedString.Key: Any], forTextInRange range: NSRange) {
        stringView.setAttributes(attributes, forTextInRange: range)
    }

    func replaceText(in range: NSRange, with string: String) {
        stringView.replaceText(in: range, with: string)
        let attributesRange = NSRange(location: range.location, length: string.utf16.count)
        stringView.setAttributes(defaultAttributes, forTextInRange: attributesRange)
    }

    func character(at location: Int) -> unichar {
        stringView.character(at: location)
    }
}

private extension ThemedStringView {
    private func reapplyDefaultAttributes() {
        let range = NSRange(location: 0, length: stringView.length)
        setAttributes(defaultAttributes, forTextInRange: range)
    }
}

