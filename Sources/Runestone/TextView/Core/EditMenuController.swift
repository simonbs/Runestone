import UIKit

struct SpellingSuggestion {
    let range: NSRange
    let original: String
    let replacement: String
    let language: String
    let revision: UInt
    let selection: NSRange?
}

struct SpellingWordAction {
    enum Kind: CaseIterable {
        case ignore
        case learn
        case unlearn

        var title: String {
            switch self {
            case .ignore:
                return L10n.Menu.ItemTitle.ignoreSpelling
            case .learn:
                return L10n.Menu.ItemTitle.learnSpelling
            case .unlearn:
                return L10n.Menu.ItemTitle.unlearnSpelling
            }
        }

        var selector: Selector {
            switch self {
            case .ignore:
                return NSSelectorFromString("ignoreSelectedSpellingWord")
            case .learn:
                return NSSelectorFromString("learnSelectedSpellingWord")
            case .unlearn:
                return NSSelectorFromString("unlearnSelectedSpellingWord")
            }
        }
    }

    let kind: Kind
    let target: SpellingSuggestion
}

protocol EditMenuControllerDelegate: AnyObject {
    func editMenuController(_ controller: EditMenuController, spellingSuggestionsFor range: NSRange) -> [SpellingSuggestion]
    func editMenuController(_ controller: EditMenuController, spellingWordActionsFor range: NSRange) -> [SpellingWordAction]
    func editMenuController(_ controller: EditMenuController, perform action: SpellingWordAction)
    func editMenuController(_ controller: EditMenuController, replace suggestion: SpellingSuggestion)
    func editMenuController(_ controller: EditMenuController, highlightedRangeFor range: NSRange) -> HighlightedRange?
    func editMenuController(_ controller: EditMenuController, canReplaceTextIn highlightedRange: HighlightedRange) -> Bool
    func editMenuController(_ controller: EditMenuController, caretRectAt location: Int) -> CGRect
    func editMenuControllerShouldReplaceText(_ controller: EditMenuController)
    func selectedRange(for controller: EditMenuController) -> NSRange?
}

final class EditMenuController: NSObject {
    weak var delegate: EditMenuControllerDelegate?
    static let spellingActionSelectors = [
        NSSelectorFromString("replaceWithFirstSpellingSuggestion"),
        NSSelectorFromString("replaceWithSecondSpellingSuggestion"),
        NSSelectorFromString("replaceWithThirdSpellingSuggestion")
    ]
    private static let spellingMenuIdentifier = "Runestone.Spelling"
    private var spellingMenuRange: NSRange?
    private var spellingMenuTargetRect: CGRect = .null
    private var legacySpellingWordActions: [SpellingWordAction] = []
    private var legacySpellingSuggestions: [SpellingSuggestion] = []

    @available(iOS 16, *)
    private var editMenuInteraction: UIEditMenuInteraction? {
        _editMenuInteraction as? UIEditMenuInteraction
    }
    private var _editMenuInteraction: Any?

    func setupEditMenu(in view: UIView) {
        if #available(iOS 16, *) {
            setupEditMenuInteraction(in: view)
        } else {
            setupMenuController()
        }
    }

    func presentEditMenu(from view: UIView, forTextIn range: NSRange) {
        let startCaretRect = caretRect(at: range.location)
        let endCaretRect = caretRect(at: range.location + range.length)
        let menuWidth = min(endCaretRect.maxX - startCaretRect.minX, view.frame.width)
        let menuRect = CGRect(x: startCaretRect.minX, y: startCaretRect.minY, width: menuWidth, height: startCaretRect.height)
        if #available(iOS 16, *) {
            let point = CGPoint(x: menuRect.midX, y: menuRect.minY)
            let configuration = UIEditMenuConfiguration(identifier: nil, sourcePoint: point)
            configuration.preferredArrowDirection = .down
            editMenuInteraction?.presentEditMenu(with: configuration)
        } else {
            updateLegacySpellingMenu()
            UIMenuController.shared.showMenu(from: view, rect: menuRect)
        }
    }

    func presentSpellingMenu(from view: UIView, forTextIn range: NSRange, targetRect: CGRect) {
        if #available(iOS 16, *) {
            spellingMenuRange = range
            spellingMenuTargetRect = targetRect
            let point = CGPoint(x: targetRect.midX, y: targetRect.maxY)
            let configuration = UIEditMenuConfiguration(identifier: Self.spellingMenuIdentifier as NSString, sourcePoint: point)
            configuration.preferredArrowDirection = .up
            editMenuInteraction?.presentEditMenu(with: configuration)
        } else {
            presentEditMenu(from: view, forTextIn: range)
        }
    }

    func dismissSpellingMenu() {
        guard spellingMenuRange != nil else {
            return
        }
        spellingMenuRange = nil
        spellingMenuTargetRect = .null
        if #available(iOS 16, *) {
            editMenuInteraction?.dismissMenu()
        }
    }

    func editMenu(for textRange: UITextRange, suggestedActions: [UIMenuElement]) -> UIMenu? {
        guard let textRange = textRange as? IndexedRange else {
            return UIMenu(children: suggestedActions)
        }
        return menu(for: textRange.range, suggestedActions: suggestedActions)
    }

    func updateLegacySpellingMenu() {
        if #available(iOS 16, *) {
            return
        }
        // Legacy menus offer corrections for selected words. Do not synchronously check the active word on every keystroke.
        if let range = delegate?.selectedRange(for: self), range.length > 0 {
            legacySpellingSuggestions = delegate?.editMenuController(self, spellingSuggestionsFor: range) ?? []
            legacySpellingWordActions = delegate?.editMenuController(self, spellingWordActionsFor: range) ?? []
        } else {
            legacySpellingSuggestions = []
            legacySpellingWordActions = []
        }
        var items = zip(legacySpellingSuggestions, Self.spellingActionSelectors).map { suggestion, selector in
            UIMenuItem(title: suggestion.replacement, action: selector)
        }
        items.append(contentsOf: legacySpellingWordActions.map { UIMenuItem(title: $0.kind.title, action: $0.kind.selector) })
        items.append(UIMenuItem(title: L10n.Menu.ItemTitle.replace, action: NSSelectorFromString("replaceTextInSelectedHighlightedRange")))
        UIMenuController.shared.menuItems = items
    }

    func hasLegacySpellingSuggestion(at index: Int) -> Bool {
        legacySpellingSuggestions.indices.contains(index)
    }

    func replaceLegacySpellingSuggestion(at index: Int) {
        guard hasLegacySpellingSuggestion(at: index) else {
            return
        }
        delegate?.editMenuController(self, replace: legacySpellingSuggestions[index])
    }

    func hasLegacySpellingWordAction(_ kind: SpellingWordAction.Kind) -> Bool {
        legacySpellingWordActions.contains { $0.kind == kind }
    }

    func performLegacySpellingWordAction(_ kind: SpellingWordAction.Kind) {
        guard let action = legacySpellingWordActions.first(where: { $0.kind == kind }) else {
            return
        }
        delegate?.editMenuController(self, perform: action)
    }

    private func menu(for range: NSRange, suggestedActions: [UIMenuElement], spellingOnly: Bool = false) -> UIMenu {
        let suggestions = delegate?.editMenuController(self, spellingSuggestionsFor: range) ?? []
        var actions: [UIMenuElement] = suggestions.map { suggestion in
            UIAction(title: suggestion.replacement) { [weak self] _ in
                guard let self = self else {
                    return
                }
                self.delegate?.editMenuController(self, replace: suggestion)
            }
        }
        let wordActions = delegate?.editMenuController(self, spellingWordActionsFor: range) ?? []
        actions.append(contentsOf: wordActions.map { action in
            UIAction(title: action.kind.title) { [weak self] _ in
                guard let self = self else {
                    return
                }
                self.delegate?.editMenuController(self, perform: action)
            }
        })
        if !spellingOnly {
            actions.append(contentsOf: suggestedActions)
            if let replaceAction = replaceActionIfAvailable(for: range) {
                actions.append(replaceAction)
            }
        }
        return UIMenu(children: actions)
    }
}

private extension EditMenuController {
    @available(iOS 16, *)
    private func setupEditMenuInteraction(in view: UIView) {
        let editMenuInteraction = UIEditMenuInteraction(delegate: self)
        _editMenuInteraction = editMenuInteraction
        view.addInteraction(editMenuInteraction)
    }

    private func setupMenuController() {
        // This is not necessary starting from iOS 16.
        let selector = NSSelectorFromString("replaceTextInSelectedHighlightedRange")
        UIMenuController.shared.menuItems = [
            UIMenuItem(title: L10n.Menu.ItemTitle.replace, action: selector)
        ]
    }

    private func highlightedRange(for range: NSRange) -> HighlightedRange? {
        delegate?.editMenuController(self, highlightedRangeFor: range)
    }

    private func canReplaceText(in highlightedRange: HighlightedRange) -> Bool {
        delegate?.editMenuController(self, canReplaceTextIn: highlightedRange) ?? false
    }

    private func caretRect(at location: Int) -> CGRect {
        delegate?.editMenuController(self, caretRectAt: location) ?? .zero
    }

    private func replaceActionIfAvailable(for range: NSRange) -> UIAction? {
        guard let highlightedRange = highlightedRange(for: range), canReplaceText(in: highlightedRange) else {
            return nil
        }
        return UIAction(title: L10n.Menu.ItemTitle.replace) { [weak self] _ in
            if let self = self {
                self.delegate?.editMenuControllerShouldReplaceText(self)
            }
        }
    }
}

@available(iOS 16, *)
extension EditMenuController: UIEditMenuInteractionDelegate {
    func editMenuInteraction(
        _ interaction: UIEditMenuInteraction,
        menuFor configuration: UIEditMenuConfiguration,
        suggestedActions: [UIMenuElement]
    ) -> UIMenu? {
        if configuration.identifier as? String == Self.spellingMenuIdentifier {
            guard let range = spellingMenuRange, delegate?.selectedRange(for: self) == range else {
                return nil
            }
            let menu = menu(for: range, suggestedActions: [], spellingOnly: true)
            return menu.children.isEmpty ? nil : menu
        }
        if let selectedRange = delegate?.selectedRange(for: self) {
            return menu(for: selectedRange, suggestedActions: suggestedActions)
        } else {
            return UIMenu(children: suggestedActions)
        }
    }

    func editMenuInteraction(_ interaction: UIEditMenuInteraction, targetRectFor configuration: UIEditMenuConfiguration) -> CGRect {
        configuration.identifier as? String == Self.spellingMenuIdentifier ? spellingMenuTargetRect : .null
    }

}
