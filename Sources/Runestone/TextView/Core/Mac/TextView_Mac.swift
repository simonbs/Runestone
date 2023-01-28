#if os(macOS)
//import AppKit
//
//public final class TextView: NSView {
//    private let textInputClientView: TextInputClientView = {
//        let this = TextInputClientView()
//        this.translatesAutoresizingMaskIntoConstraints = false
//        return this
//    }()
//
//    public init() {
//        super.init(frame: .zero)
//        wantsLayer = true
//    }
//
//    required init?(coder: NSCoder) {
//        fatalError("init(coder:) has not been implemented")
//    }
//
//    public override func keyDown(with event: NSEvent) {
//        NSCursor.setHiddenUntilMouseMoves(true)
//        let didInputContextHandleEvent = inputContext?.handleEvent(event) ?? false
//        if !didInputContextHandleEvent {
//            super.keyDown(with: event)
//        }
//    }
//}
//
//private extension TextView {
//    private func setupTextInputClientView() {
//        addSubview(textInputClientView)
//        NSLayoutConstraint.activate([
//            textInputClientView.leadingAnchor.constraint(equalTo: leadingAnchor),
//            textInputClientView.trailingAnchor.constraint(equalTo: trailingAnchor),
//            textInputClientView.topAnchor.constraint(equalTo: topAnchor),
//            textInputClientView.bottomAnchor.constraint(equalTo: bottomAnchor)
//        ])
//    }
//}
#endif
