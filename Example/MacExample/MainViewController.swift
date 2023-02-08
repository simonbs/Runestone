import Cocoa
import Runestone
import RunestoneJavaScriptLanguage
import RunestoneOneDarkTheme
import RunestoneThemeCommon
import RunestoneTomorrowNightTheme
import RunestoneTomorrowTheme

final class MainViewController: NSViewController {
    private let theme: EditorTheme = OneDarkTheme()
    private let textView: TextView = {
        let this = TextView()
        this.translatesAutoresizingMaskIntoConstraints = false
        this.textContainerInset = NSEdgeInsets(top: 0, left: 5, bottom: 0, right: 5)
        this.showLineNumbers = true
        this.showTabs = true
        this.showSpaces = true
        this.showLineBreaks = true
        this.showSoftLineBreaks = true
        this.lineHeightMultiplier = 1.3
        this.kern = 0.3
        this.lineSelectionDisplayType = .line
        this.gutterLeadingPadding = 4
        this.gutterTrailingPadding = 4
        this.isLineWrappingEnabled = true
        this.indentStrategy = .space(length: 2)
        this.characterPairs = [
            BasicCharacterPair(leading: "(", trailing: ")"),
            BasicCharacterPair(leading: "{", trailing: "}"),
            BasicCharacterPair(leading: "[", trailing: "]"),
            BasicCharacterPair(leading: "\"", trailing: "\""),
            BasicCharacterPair(leading: "'", trailing: "'")
        ]
        return this
    }()

    override var acceptsFirstResponder: Bool {
        true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.appearance = NSAppearance(named: .vibrantDark)
        setupTextView()
        applyTheme(theme)
        // swiftlint:disable line_length
        let text = """
Lorem ipsum dolor sit amet, consectetur adipiscing elit. Aliquam ante ex, imperdiet in placerat eu, commodo ac dui. Fusce tincidunt facilisis eros condimentum varius. Ut tellus est, luctus pulvinar rutrum ac, semper at eros. Vestibulum et molestie dui. Nulla sagittis ipsum a dolor consectetur, ut ultrices turpis egestas. Quisque eleifend feugiat massa eget egestas. Donec sed ipsum sed lectus sodales sagittis at sit amet ipsum. Ut facilisis, augue vitae feugiat auctor, lacus metus feugiat augue, quis dictum quam ipsum nec felis. Donec nec orci justo. Pellentesque in est eu dui semper pulvinar. Donec at porta augue, a facilisis magna.

Etiam lacinia et erat et luctus. Phasellus sit amet semper nisi. In nec nulla sit amet est elementum consequat eget sed magna. Maecenas tincidunt augue nec diam egestas dapibus. Cras porta vulputate ex ac fringilla. Proin rhoncus turpis sed hendrerit laoreet. Duis faucibus leo non posuere vulputate. Cras blandit dolor nibh, sit amet luctus massa commodo eget. Praesent a tempus leo, vel pretium urna. Quisque et sollicitudin neque. Morbi pellentesque felis pretium lectus molestie egestas. Suspendisse efficitur odio ac metus vehicula, eget cursus elit fermentum. Nunc maximus lectus eu erat volutpat iaculis. In elementum, risus nec commodo sollicitudin, diam est lobortis justo, vitae consequat erat dolor eu tellus. Pellentesque varius diam at urna eleifend maximus.

Sed sagittis lectus id turpis bibendum, nec iaculis libero malesuada. Etiam nec ipsum vel tellus vestibulum sollicitudin ac ac nunc. Mauris non est vel sapien condimentum feugiat vel ullamcorper arcu. Duis a ligula quis justo ultrices feugiat at vel urna. Praesent erat turpis, convallis a feugiat ac, dictum a justo. Suspendisse venenatis tincidunt massa, nec mollis diam pretium lacinia. Cras non erat ut mauris iaculis lacinia. Cras accumsan purus vitae metus semper, non commodo arcu ullamcorper. Pellentesque porttitor lobortis ipsum, porta accumsan enim viverra ut. Duis ut tortor eget libero vulputate porttitor. Nulla bibendum libero tellus, sed mattis turpis feugiat non.

Nunc lacus augue, tempus eu metus non, venenatis blandit massa. Donec consectetur cursus nibh eget iaculis. Pellentesque vel sem non tellus elementum rhoncus tempus quis est. In in neque sed ligula fermentum faucibus egestas in mauris. Vivamus id nunc non enim iaculis venenatis at vitae orci. Cras nec lacus nec nulla cursus rutrum. Donec vitae dui eget tellus tincidunt pharetra pulvinar id lacus.

Sed et metus imperdiet, viverra lectus at, convallis justo. Suspendisse quis massa sodales, blandit ante vitae, mattis diam. Suspendisse potenti. Sed non odio aliquet, viverra purus quis, rhoncus lectus. Integer dignissim scelerisque lectus ut sagittis. Nunc ac nunc elit. Donec ligula nunc, egestas sed purus sed, ultrices dignissim eros. Ut accumsan porta velit, nec condimentum eros pellentesque et. Nunc ut ante eu turpis consectetur euismod sit amet quis urna. Duis nibh elit, dapibus vitae luctus in, placerat a mauris. Curabitur tincidunt venenatis nisl vitae euismod. Sed tristique sapien purus, sit amet auctor urna sodales a.
"""
        // swiftlint:enable line_length
        let state = TextViewState(text: text, theme: theme, language: .javaScript)
        textView.setState(state)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.backgroundColor = theme.backgroundColor
    }
}

private extension MainViewController {
    private func setupTextView() {
        view.addSubview(textView)
        NSLayoutConstraint.activate([
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            textView.topAnchor.constraint(equalTo: view.topAnchor),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func applyTheme(_ theme: EditorTheme) {
        textView.theme = theme
        textView.wantsLayer = true
        textView.layer?.backgroundColor = theme.backgroundColor.cgColor
        textView.insertionPointColor = theme.textColor
        textView.selectionHighlightColor = theme.textColor.withAlphaComponent(0.2)
    }
}
