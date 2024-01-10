import UIKit

final class MenuButton: UIButton {
    private weak var selectionHandler: MenuSelectionHandler?

    static func makeConfigured(with selectionHandler: MenuSelectionHandler) -> UIButton {
        var configuration: UIButton.Configuration = .plain()
        configuration.image = UIImage(systemName: "ellipsis")
        let button = MenuButton(configuration: configuration)
        button.selectionHandler = selectionHandler
        button.showsMenuAsPrimaryAction = true
        button.setupMenu()
        return button
    }
}

private extension MenuButton {
    private func setupMenu() {
        menu = UIMenu(children: makeFeaturesMenuElements() + makeSettingsMenuElements() + makeThemeMenuElements())
    }
}

private extension MenuButton {
    private func makeFeaturesMenuElements() -> [UIMenuElement] {
        var menuElements: [UIMenuElement] = []
        if #available(iOS 16, *) {
            menuElements += [
                UIMenu(options: .displayInline, children: [
                    UIAction(title: "Find") { [weak self] _ in
                        self?.selectionHandler?.handleSelection(of: .presentFind)
                    },
                    UIAction(title: "Find and Replace") { [weak self] _ in
                        self?.selectionHandler?.handleSelection(of: .presentFindAndReplace)
                    }
                ])
            ]
        }
        menuElements += [
            UIAction(title: "Go to Line") { [weak self] _ in
                self?.selectionHandler?.handleSelection(of: .presentGoToLine)
            }
        ]
        return menuElements
    }

    private func makeSettingsMenuElements() -> [UIMenuElement] {
        let settings = UserDefaults.standard
        return [
            UIMenu(options: .displayInline, children: [
                UIAction(title: "Show Line Numbers", state: settings.showLineNumbers ? .on : .off) { [weak self] _ in
                    self?.selectionHandler?.handleSelection(of: .toggleLineNumbers)
                    self?.setupMenu()
                },
                UIAction(title: "Show Page Guide", state: settings.showPageGuide ? .on : .off) { [weak self] _ in
                    self?.selectionHandler?.handleSelection(of: .togglePageGuide)
                    self?.setupMenu()
                },
                UIAction(title: "Show Invisible Characters", state: settings.showInvisibleCharacters ? .on : .off) { [weak self] _ in
                    self?.selectionHandler?.handleSelection(of: .toggleInvisibleCharacters)
                    self?.setupMenu()
                },
                UIAction(title: "Wrap Lines", state: settings.wrapLines ? .on : .off) { [weak self] _ in
                    self?.selectionHandler?.handleSelection(of: .toggleWrapLines)
                    self?.setupMenu()
                },
                UIAction(title: "Highlight Selected Line", state: settings.highlightSelectedLine ? .on : .off) { [weak self] _ in
                    self?.selectionHandler?.handleSelection(of: .toggleHighlightSelectedLine)
                    self?.setupMenu()
                }
            ]),
            UIMenu(options: .displayInline, children: [
                UIAction(title: "Allow Editing", state: settings.isEditable ? .on : .off) { [weak self] _ in
                    self?.selectionHandler?.handleSelection(of: .toggleEditable)
                    self?.setupMenu()
                },
                UIAction(title: "Allow Selection", state: settings.isSelectable ? .on : .off) { [weak self] _ in
                    self?.selectionHandler?.handleSelection(of: .toggleSelectable)
                    self?.setupMenu()
                }
            ])
        ]
    }

    private func makeThemeMenuElements() -> [UIMenuElement] {
        [
            UIAction(title: "Theme") { [weak self] _ in
                self?.selectionHandler?.handleSelection(of: .presentThemePicker)
            }
        ]
    }
}
