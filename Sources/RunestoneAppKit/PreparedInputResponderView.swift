#if canImport(AppKit)
import AppKit

/// Internal first-responder experiment. It is not a public editor surface.
/// The document attachment owns the adapter and connection; this view holds
/// both weakly so retaining a view cannot keep its document alive.
final class PreparedInputResponderView: ReadOnlyDocumentView,
                                        PreparedInputContextConnection.ReadyObserver,
                                        PreparedInputContextConnection.CommandHandler {
    private weak var inputAdapter: PreparedInputEventAdapter?
    private weak var inputConnection: PreparedInputContextConnection?
    private var focusGeneration = UUID()
    private var keyObservers: [NSObjectProtocol] = []
    private var interpretingKeyEvents = false
    private var commandGeneration = UUID()

    init(snapshot: NSAttributedString) {
        super.init(snapshot: snapshot, fallbackHeight: 16)
    }

    required init?(coder: NSCoder) { nil }

    func attach(adapter: PreparedInputEventAdapter, connection: PreparedInputContextConnection) {
        precondition(Thread.isMainThread && inputConnection == nil && inputAdapter == nil)
        inputAdapter = adapter
        inputConnection = connection
        connection.readyObserver = self
        connection.commandHandler = self
        scheduleFocusCheck()
    }

    private var ownsKeyFocus: Bool {
        guard !isRetired, let window = window else { return false }
        return window.isKeyWindow && window.firstResponder === self
    }

    override func accessibilityTextState() -> AccessibilityTextState? {
        inputConnection?.accessibilityTextState()
    }

    override var acceptsFirstResponder: Bool { !isRetired && inputConnection != nil }

    override var inputContext: NSTextInputContext? {
        guard ownsKeyFocus else { return nil }
        return inputConnection?.currentInputContext
    }

    override func becomeFirstResponder() -> Bool {
        guard !isRetired, inputConnection != nil, super.becomeFirstResponder() else { return false }
        scheduleFocusCheck()
        needsDisplay = true
        return true
    }

    override func resignFirstResponder() -> Bool {
        suppressFocus()
        let accepted = super.resignFirstResponder()
        if !accepted { scheduleFocusCheck() }
        needsDisplay = true
        return accepted
    }

    override func viewDidMoveToWindow() {
        keyObservers.forEach { NotificationCenter.default.removeObserver($0) }
        keyObservers.removeAll()
        super.viewDidMoveToWindow()
        guard let window = window, !isRetired else { suppressFocus(); return }
        keyObservers.append(NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification,
                                                                     object: window, queue: .main) { [weak self] _ in
            self?.scheduleFocusCheck()
        })
        keyObservers.append(NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification,
                                                                     object: window, queue: .main) { [weak self] _ in
            self?.suppressFocus()
        })
        if ownsKeyFocus { scheduleFocusCheck() } else { suppressFocus() }
    }

    private func suppressFocus() {
        focusGeneration = UUID()
        inputConnection?.suspendForFocusLoss()
        needsDisplay = true
    }

    private func scheduleFocusCheck() {
        let generation = UUID()
        focusGeneration = generation
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.focusGeneration == generation,
                  self.ownsKeyFocus, let connection = self.inputConnection else { return }
            _ = connection.resumeForFocus()
            guard self.focusGeneration == generation, self.ownsKeyFocus else {
                connection.suspendForFocusLoss()
                return
            }
            self.needsDisplay = true
        }
    }

    func preparedInputContextConnectionDidBecomeReady(_ connection: PreparedInputContextConnection) {
        guard inputConnection === connection else { return }
        scheduleFocusCheck()
    }

    override func keyDown(with event: NSEvent) {
        guard ownsKeyFocus, let connection = inputConnection else { super.keyDown(with: event); return }
        let beforeCommands = commandGeneration
        let beforeContent = contentRevision
        let beforeGeometry = inputGeometryRevision
        let handled = connection.handle(event)
        guard ownsKeyFocus, inputConnection === connection, !isRetired else { return }
        if handled || commandGeneration != beforeCommands || contentRevision != beforeContent ||
            inputGeometryRevision != beforeGeometry { return }
        // The input context has declined the event. Key bindings fall back to
        // insertText: or doCommandBySelector:, guarded below by focus/activity.
        _ = connection.performKeyBindingFallback {
            guard ownsKeyFocus, inputConnection === connection, !interpretingKeyEvents else { return }
            interpretingKeyEvents = true
            defer { interpretingKeyEvents = false }
            interpretKeyEvents([event])
        }
    }

    @objc(insertText:)
    func insertTextFromKeyBinding(_ value: Any) {
        guard interpretingKeyEvents, ownsKeyFocus, let connection = inputConnection else { return }
        connection.insertTextFromKeyBinding(value, replacementRange: NSRange(location: NSNotFound, length: 0))
    }

    @objc(doCommandBySelector:)
    func doCommandFromKeyBinding(_ selector: Selector) {
        guard interpretingKeyEvents, ownsKeyFocus, let connection = inputConnection else { return }
        connection.doCommandFromKeyBinding(selector)
    }

    func preparedInputContextConnection(_ connection: PreparedInputContextConnection, doCommand selector: Selector) {
        guard inputConnection === connection, ownsKeyFocus, let adapter = inputAdapter else { return }
        commandGeneration = UUID()
        if let outcome = PreparedInputCommandInterpreter.perform(selector, adapter: adapter, view: self) {
            if outcome != .processed { connection.requestReset() }
        } else {
            _ = nextResponder?.tryToPerform(selector, with: self)
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard !isRetired, let window = window else { return }
        guard window.makeFirstResponder(self), ownsKeyFocus, let connection = inputConnection else { return }
        // A first click can arrive before the scheduled focus check runs.
        guard connection.resumeForFocus(), ownsKeyFocus else { return }
        connection.performResponderActivity { adapter, isCurrent in
            guard adapter.hasProvisionalCompositionForInput() == false,
                  !adapter.needsInputReset, isCurrent(), ownsKeyFocus else { return }
            let screenPoint = window.convertPoint(toScreen: event.locationInWindow)
            guard isCurrent(), ownsKeyFocus,
                  let offset = InputScreenRangeGeometry.characterIndex(for: screenPoint, in: self),
                  isCurrent(), ownsKeyFocus else { return }
            if adapter.setSelection(NSRange(location: offset, length: 0)) != .processed { connection.requestReset() }
            needsDisplay = true
        }
    }

    override func noteInputCoordinatesChanged() {
        super.noteInputCoordinatesChanged()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard ownsKeyFocus, let connection = inputConnection else { return }
        connection.performResponderActivity { adapter, isCurrent in
            let selection = adapter.selectedRangeForInput()
            guard selection.location != NSNotFound, isCurrent(), ownsKeyFocus else { return }
            let marked = adapter.markedRangeForInput()
            guard !adapter.needsInputReset, isCurrent(), ownsKeyFocus,
                  let geometry = InputSelectionGeometry.geometry(selection: selection,
                      marked: marked.location == NSNotFound ? nil : marked, in: self),
                  isCurrent(), ownsKeyFocus else { return }
            NSColor.selectedTextBackgroundColor.withAlphaComponent(0.35).setFill()
            for rect in geometry.selectionRects where rect.intersects(dirtyRect) { NSBezierPath(rect: rect).fill() }
            NSColor.textColor.setFill()
            for rect in geometry.markedRects where rect.intersects(dirtyRect) {
                NSBezierPath(rect: NSRect(x: rect.minX, y: rect.maxY - 1, width: rect.width, height: 1)).fill()
            }
            if let caret = geometry.caretRect, caret.intersects(dirtyRect) { NSBezierPath(rect: caret).fill() }
        }
    }

    deinit { keyObservers.forEach { NotificationCenter.default.removeObserver($0) } }
}
#endif
