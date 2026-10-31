#if canImport(AppKit)
import AppKit
import ObjectiveC

/// A query-only context lifecycle seam. It does not enable editing or focus.
/// All operations and AppKit client callbacks must run on the main thread.
final class InputContextConnection {
    protocol Driver: AnyObject {
        var associationTarget: NSObject { get }
        func activate()
        func invalidateCoordinates()
        func deactivate()
    }
    typealias DriverFactory = (NSTextInputClient) -> Driver
    private enum State { case connected, disconnecting, disconnected }
    private let view: ReadOnlyDocumentView
    private let permit: ReadOnlyDocumentView.InputMutationPermit
    private let proxy: QueryOnlyClient
    private var driver: Driver?
    private var state: State = .connected
    private var active = false
    private var driverCallDepth = 0
    private var deferredInvalidation = false

    init?(view: ReadOnlyDocumentView, makeDriver: DriverFactory? = nil) {
        precondition(Thread.isMainThread)
        guard let permit = view.claimInputMutation() else { return nil }
        let client = DocumentInputClient(view: view, mutationPermit: permit,
                                         typingAttributes: { [:] }, commandHandler: { _ in },
                                         rectProvider: { [weak view] range in
                                             guard let view = view else { return nil }
                                             return InputScreenRangeGeometry.firstRect(for: range, in: view)
                                         }, indexProvider: { [weak view] point in
                                             guard let view = view else { return nil }
                                             return InputScreenRangeGeometry.characterIndex(for: point, in: view)
                                         })
        let proxy = QueryOnlyClient(client)
        let driver = makeDriver?(proxy) ?? AppKitDriver(client: proxy)
        guard objc_getAssociatedObject(driver.associationTarget, &contextClientKey) == nil else {
            proxy.detach()
            precondition(view.releaseInputMutation(permit))
            return nil
        }
        objc_setAssociatedObject(driver.associationTarget, &contextClientKey, proxy, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        self.view = view
        self.permit = permit
        self.proxy = proxy
        self.driver = driver
        view.inputInvalidation.attach { [weak self] in self?.invalidateCoordinates() }
    }

    /// Repeated activation is a no-op and reports that the connection is active.
    @discardableResult
    func activate() -> Bool {
        precondition(Thread.isMainThread)
        guard state == .connected, driverCallDepth == 0, let driver = driver else { return false }
        if active { return true }
        active = true
        driverCallDepth += 1
        defer { finishDriverCall() }
        driver.activate()
        return true
    }

    private func invalidateCoordinates() {
        precondition(Thread.isMainThread)
        guard state == .connected, active else { return }
        guard driverCallDepth == 0 else { deferredInvalidation = true; return }
        guard let driver = driver else { return }
        driverCallDepth += 1
        defer { finishDriverCall() }
        driver.invalidateCoordinates()
    }

    private func finishDriverCall() {
        driverCallDepth -= 1
        if driverCallDepth == 0 && deferredInvalidation && state == .connected {
            deferredInvalidation = false
            view.inputInvalidation.invalidate()
        }
    }

    /// Deactivation may query the client. Retained contexts become inert after it returns.
    @discardableResult
    func disconnect() -> Bool {
        precondition(Thread.isMainThread)
        guard state == .connected, driverCallDepth == 0, !proxy.isQuerying,
              !view.inputMutationInFlight, let driver = driver else { return false }
        state = .disconnecting
        view.inputInvalidation.detach()
        if active { driver.deactivate() }
        proxy.detach()
        precondition(view.releaseInputMutation(permit))
        self.driver = nil
        state = .disconnected
        return true
    }

    deinit {
        guard let driver = driver else { return }
        let view = view
        let permit = permit
        let proxy = proxy
        let active = active
        DispatchQueue.main.async {
            // A nested event loop can run this while an AppKit query is on the stack.
            proxy.whenIdle {
                view.inputInvalidation.detach()
                if active { driver.deactivate() }
                proxy.detach()
                view.releaseInputMutationWhenIdle(permit)
            }
        }
    }
}

private var contextClientKey: UInt8 = 0

/// The associated proxy never retains the context. Once detached it owns no view.
final class QueryOnlyClient: NSObject, NSTextInputClient {
    private var client: DocumentInputClient?
    private var queryDepth = 0
    private var idleWork: (() -> Void)?
    var isQuerying: Bool { queryDepth != 0 }
    init(_ client: DocumentInputClient) { self.client = client }
    func detach() { precondition(Thread.isMainThread && !isQuerying); client = nil }
    func whenIdle(_ work: @escaping () -> Void) {
        precondition(Thread.isMainThread && idleWork == nil)
        if isQuerying { idleWork = work } else { work() }
    }
    private func query<T>(_ fallback: T, _ body: (DocumentInputClient) -> T) -> T {
        precondition(Thread.isMainThread)
        guard let client = client else { return fallback }
        queryDepth += 1
        defer {
            queryDepth -= 1
            if queryDepth == 0, let work = idleWork {
                idleWork = nil
                // Leave the AppKit callback stack before attempting cleanup.
                DispatchQueue.main.async { [self] in whenIdle(work) }
            }
        }
        return body(client)
    }
    func insertText(_ string: Any, replacementRange: NSRange) { precondition(Thread.isMainThread) }
    func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) { precondition(Thread.isMainThread) }
    func unmarkText() { precondition(Thread.isMainThread) }
    func doCommand(by selector: Selector) { precondition(Thread.isMainThread) }
    func selectedRange() -> NSRange { query(NSRange(location: NSNotFound, length: 0)) { $0.selectedRange() } }
    func markedRange() -> NSRange { query(NSRange(location: NSNotFound, length: 0)) { $0.markedRange() } }
    func hasMarkedText() -> Bool { query(false) { $0.hasMarkedText() } }
    func validAttributesForMarkedText() -> [NSAttributedString.Key] { query([]) { $0.validAttributesForMarkedText() } }
    func attributedSubstring(forProposedRange range: NSRange, actualRange: NSRangePointer?) -> NSAttributedString? {
        actualRange?.pointee = NSRange(location: NSNotFound, length: 0)
        return query(nil) { $0.attributedSubstring(forProposedRange: range, actualRange: actualRange) }
    }
    func firstRect(forCharacterRange range: NSRange, actualRange: NSRangePointer?) -> NSRect {
        actualRange?.pointee = NSRange(location: NSNotFound, length: 0)
        return query(.zero) { $0.firstRect(forCharacterRange: range, actualRange: actualRange) }
    }
    func characterIndex(for point: NSPoint) -> Int { query(NSNotFound) { $0.characterIndex(for: point) } }
}

private final class AppKitDriver: InputContextConnection.Driver {
    private let context: NSTextInputContext
    init(client: NSTextInputClient) { context = NSTextInputContext(client: client) }
    var associationTarget: NSObject { context }
    func activate() { context.activate() }
    func invalidateCoordinates() { context.invalidateCharacterCoordinates() }
    func deactivate() { context.deactivate() }
}
#endif
