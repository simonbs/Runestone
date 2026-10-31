#if canImport(AppKit)
import AppKit
import ObjectiveC

/// Internal input-context lifecycle for a prepared session. This is not a view,
/// event responder, or public editor. All operations run on the main thread.
final class PreparedInputContextConnection {
    protocol Driver: AnyObject {
        var associationTarget: NSObject { get }
        func activate()
        func handle(_ event: NSEvent) -> Bool
        func invalidateCoordinates()
        func discardMarkedText()
        func deactivate()
    }
    typealias DriverFactory = (NSTextInputClient) -> Driver
    private enum State { case connected, resetRequested, quiescing, reconstructing, waiting, disconnected }

    private let adapter: PreparedInputEventAdapter
    private let view: ReadOnlyDocumentView
    private let makeDriver: DriverFactory
    // Must enqueue asynchronously without running a nested event loop.
    private let schedule: (@escaping () -> Void) -> Void
    private let blocked: () -> Void
    private var state: State = .connected
    private var driver: Driver?
    private var proxy: PreparedContextClient?
    private var contextToken: PreparedInputEventAdapter.InputContextToken?
    private var activated = false
    private var driverDepth = 0
    private var callbackDepth = 0
    private var drainScheduled = false
    private var generation = UUID()
    private var deferredInvalidation = false
    private var wantsDisconnect = false
    private var resetDuringReconstruction = false
    private var notifyingBlocked = false
    private var retryRequestedDuringBlocked = false
    private var gateReleaseDuringReconstruction = false
    private var blockedRetryGeneration = UUID()

    init?(adapter: PreparedInputEventAdapter, view: ReadOnlyDocumentView,
          makeDriver: DriverFactory? = nil,
          schedule: @escaping (@escaping () -> Void) -> Void = { DispatchQueue.main.async(execute: $0) },
          blocked: @escaping () -> Void = {}) {
        precondition(Thread.isMainThread)
        guard adapter.ownsInputView(view), let token = adapter.claimInputContext() else { return nil }
        self.adapter = adapter
        self.view = view
        self.makeDriver = makeDriver ?? { AppKitPreparedDriver(client: $0) }
        self.schedule = schedule
        self.blocked = blocked
        self.contextToken = token
        guard installDriver() else {
            precondition(adapter.releaseInputContext(token))
            self.contextToken = nil
            return nil
        }
    }

    private func installDriver() -> Bool {
        let client = PreparedContextClient()
        // The context may query attributes during initialization. An unattached
        // client returns inert values until its complete lifetime is established.
        let newDriver = makeDriver(client)
        guard objc_getAssociatedObject(newDriver.associationTarget, &preparedContextClientKey) == nil else { return false }
        objc_setAssociatedObject(newDriver.associationTarget, &preparedContextClientKey, client, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        client.owner = self
        driver = newDriver
        proxy = client
        view.inputInvalidation.attach { [weak self] in self?.invalidateCoordinates() }
        return true
    }

    @discardableResult
    func activate() -> Bool {
        precondition(Thread.isMainThread)
        guard state == .connected, driverDepth == 0, callbackDepth == 0, let driver = driver else { return false }
        if activated { return true }
        activated = true
        driverDepth += 1
        defer { finishDriverCall() }
        driver.activate()
        return state == .connected
    }

    @discardableResult
    func handle(_ event: NSEvent) -> Bool {
        precondition(Thread.isMainThread)
        guard state == .connected, activated, driverDepth == 0, callbackDepth == 0, let driver = driver else { return false }
        driverDepth += 1
        defer { finishDriverCall() }
        return driver.handle(event)
    }

    private func invalidateCoordinates() {
        guard state == .connected, activated else { return }
        guard driverDepth == 0, callbackDepth == 0 else { deferredInvalidation = true; return }
        guard let driver = driver else { return }
        driverDepth += 1
        defer { finishDriverCall() }
        driver.invalidateCoordinates()
    }

    private func finishDriverCall() {
        driverDepth -= 1
        finishActivity()
    }

    private func finishActivity() {
        if driverDepth == 0 && callbackDepth == 0 && deferredInvalidation && state == .connected {
            deferredInvalidation = false
            view.inputInvalidation.invalidate()
        }
        scheduleDrainIfNeeded()
    }

    fileprivate func query<T>(_ fallback: T, _ action: (PreparedInputEventAdapter) -> T) -> T {
        precondition(Thread.isMainThread)
        guard state == .connected else { return fallback }
        callbackDepth += 1
        defer { callbackDepth -= 1; finishActivity() }
        let result = action(adapter)
        if adapter.needsInputReset { requestReset() }
        return state == .connected ? result : fallback
    }

    fileprivate func mutate(_ action: (PreparedInputEventAdapter) -> PreparedInputEventAdapter.Outcome) {
        precondition(Thread.isMainThread)
        guard state == .connected else { return }
        callbackDepth += 1
        defer { callbackDepth -= 1; finishActivity() }
        if action(adapter) != .processed { requestReset() }
    }

    /// Suppress callbacks immediately, but never discard on the triggering stack.
    func requestReset() {
        precondition(Thread.isMainThread)
        if state == .reconstructing { resetDuringReconstruction = true; return }
        guard state == .connected else { return }
        state = .resetRequested
        generation = UUID()
        scheduleDrainIfNeeded()
    }

    private func scheduleDrainIfNeeded() {
        guard state == .resetRequested, !drainScheduled else { return }
        drainScheduled = true
        let expected = generation
        schedule { [weak self] in
            guard let self = self, self.generation == expected else { return }
            self.drainScheduled = false
            self.drainReset()
        }
    }

    private func drainReset() {
        guard state == .resetRequested, driverDepth == 0, callbackDepth == 0,
              driver != nil, contextToken != nil else { return }
        state = .quiescing
        view.inputInvalidation.detach()
        // Disarm before waiting: even nested AppKit callbacks are now inert.
        proxy?.owner = nil
        let expected = generation
        adapter.whenInputActivityIdle { [weak self] in
            guard let self = self, self.state == .quiescing, self.generation == expected,
                  let driver = self.driver, let token = self.contextToken else { return }
            self.driverDepth += 1
            driver.discardMarkedText()
            if self.activated { driver.deactivate() }
            self.driverDepth -= 1
            self.driver = nil
            self.proxy = nil
            self.activated = false
            precondition(self.adapter.releaseInputContext(token))
            self.contextToken = nil
            self.state = .waiting
            // The adapter's idle-work guard must unwind before reconstruction.
            self.schedule { [weak self] in
                guard let self = self, self.generation == expected else { return }
                self.resumeAfterQuiescing()
            }
        }
    }

    /// Call after an actual document-gate release or stale snapshot becoming
    /// ready. The host must send a new signal for every later gate release; a
    /// blocked callback is an advisory notification, not a polling mechanism.
    func resumeAfterQuiescing() {
        resumeAfterQuiescing(isBlockedRetry: false)
    }

    /// A real gate release may arrive in a nested event loop while a previous
    /// reconstruction still has callouts on the stack. Preserve that wakeup.
    func documentGateDidBecomeAvailable() {
        precondition(Thread.isMainThread)
        if state == .reconstructing {
            gateReleaseDuringReconstruction = true
            return
        }
        resumeAfterQuiescing()
    }

    private func resumeAfterQuiescing(isBlockedRetry: Bool) {
        precondition(Thread.isMainThread)
        guard state == .waiting else { return }
        if notifyingBlocked {
            retryRequestedDuringBlocked = true
            return
        }
        // A newer attempt supersedes any previously queued readiness signal.
        blockedRetryGeneration = UUID()
        state = .reconstructing
        resetDuringReconstruction = false
        gateReleaseDuringReconstruction = false
        switch adapter.reconstructWithoutInputContext() {
        case .processed:
            break
        case .resetRequired:
            notifyBlocked(suppressRetry: isBlockedRetry)
            return
        case .unavailable:
            guard adapter.inputActivityIsBusy else { notifyBlocked(suppressRetry: isBlockedRetry); return }
            // A nested run loop can deliver the scheduled resume while the
            // adapter's idle cleanup is still unwinding. Retry only after its
            // activity guard becomes idle, rather than treating a queued turn
            // as proof that cleanup completed.
            state = .waiting
            let expected = generation
            adapter.whenInputActivityIdle { [weak self] in
                guard let self = self, self.state == .waiting, self.generation == expected else { return }
                self.schedule { [weak self] in
                    guard let self = self, self.generation == expected else { return }
                    self.resumeAfterQuiescing()
                }
            }
            return
        }
        if wantsDisconnect {
            guard adapter.disconnectAfterQuiescing() else { notifyBlocked(suppressRetry: isBlockedRetry); return }
            state = .disconnected
            return
        }
        guard let token = adapter.claimInputContext() else { notifyBlocked(suppressRetry: isBlockedRetry); return }
        contextToken = token
        guard installDriver() else {
            precondition(adapter.releaseInputContext(token))
            contextToken = nil
            notifyBlocked(suppressRetry: isBlockedRetry)
            return
        }
        state = .connected
        // Driver construction and revision checks may call out and request a
        // close or a newer reset. Do not lose either intent on installation.
        if wantsDisconnect { _ = disconnect(); return }
        if resetDuringReconstruction { requestReset(); return }
        // Focus ownership belongs to the future view host. It decides whether
        // to reactivate this fresh context after a reset.
    }

    private func notifyBlocked(suppressRetry: Bool) {
        state = .waiting
        let receivedGateRelease = gateReleaseDuringReconstruction
        gateReleaseDuringReconstruction = false
        retryRequestedDuringBlocked = false
        if !suppressRetry {
            notifyingBlocked = true
            blocked()
            notifyingBlocked = false
        }
        guard receivedGateRelease || retryRequestedDuringBlocked else { return }
        retryRequestedDuringBlocked = false
        let expected = generation
        let retry = UUID()
        blockedRetryGeneration = retry
        schedule { [weak self] in
            guard let self = self, self.generation == expected,
                  self.blockedRetryGeneration == retry else { return }
            // A newly observed gate release may warrant one more attempt.
            // An advisory blocked callback alone cannot cause polling.
            self.resumeAfterQuiescing(isBlockedRetry: true)
        }
    }

    var isDisconnected: Bool { state == .disconnected }

    /// A close intent survives callbacks, reset, and a temporarily busy document.
    /// Returns true only after reconstruction and disconnection have completed.
    @discardableResult
    func disconnect() -> Bool {
        precondition(Thread.isMainThread)
        if state == .disconnected { return true }
        wantsDisconnect = true
        switch state {
        case .connected:
            state = .resetRequested
            generation = UUID()
            if driverDepth == 0 && callbackDepth == 0 { drainReset() }
            else { scheduleDrainIfNeeded() }
        case .resetRequested:
            scheduleDrainIfNeeded()
        case .waiting:
            resumeAfterQuiescing()
        case .quiescing, .reconstructing, .disconnected:
            break
        }
        return state == .disconnected
    }

    deinit {
        let view = view
        let adapter = adapter
        let driver = driver
        let token = contextToken
        let client = proxy
        let activated = activated
        let shouldRetire = state != .disconnected
        let retained = (makeDriver, schedule, blocked)
        // Mark synchronously, even on an off-main final release. AppKit cleanup
        // and all final releases occur later on main, after adapter activity.
        if shouldRetire { view.retireInputView() }
        DispatchQueue.main.async {
            withExtendedLifetime(retained) {
                guard shouldRetire else { return }
                adapter.whenInputActivityIdle {
                    view.inputInvalidation.detach()
                    driver?.discardMarkedText()
                    if activated { driver?.deactivate() }
                    if let token = token { _ = adapter.releaseInputContext(token) }
                    withExtendedLifetime(client) {}
                }
            }
        }
    }
}

private var preparedContextClientKey: UInt8 = 0

/// The associated proxy never owns its context, adapter, view, or coordinator.
private final class PreparedContextClient: NSObject, NSTextInputClient {
    weak var owner: PreparedInputContextConnection?
    func insertText(_ string: Any, replacementRange: NSRange) {
        owner?.mutate { $0.insertText(string, replacementRange: replacementRange) }
    }
    func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        owner?.mutate { $0.setMarkedText(string, selectedRange: selectedRange, replacementRange: replacementRange) }
    }
    func unmarkText() { owner?.mutate { $0.unmarkText() } }
    func doCommand(by selector: Selector) {} // Commands require a real responder and are not yet supported.
    func selectedRange() -> NSRange {
        owner?.query(NSRange(location: NSNotFound, length: 0)) { $0.selectedRangeForInput() }
            ?? NSRange(location: NSNotFound, length: 0)
    }
    func markedRange() -> NSRange {
        owner?.query(NSRange(location: NSNotFound, length: 0)) { $0.markedRangeForInput() }
            ?? NSRange(location: NSNotFound, length: 0)
    }
    func hasMarkedText() -> Bool { markedRange().location != NSNotFound }
    func validAttributesForMarkedText() -> [NSAttributedString.Key] { [] }
    func attributedSubstring(forProposedRange range: NSRange, actualRange: NSRangePointer?) -> NSAttributedString? {
        actualRange?.pointee = NSRange(location: NSNotFound, length: 0)
        var actual = NSRange(location: NSNotFound, length: 0)
        guard let result = owner?.query(nil, { $0.attributedSubstringForInput(range: range, actualRange: &actual) }) else { return nil }
        actualRange?.pointee = actual
        return result
    }
    func firstRect(forCharacterRange range: NSRange, actualRange: NSRangePointer?) -> NSRect {
        actualRange?.pointee = NSRange(location: NSNotFound, length: 0)
        let result: (NSRect, NSRange)? = owner?.query(nil) { adapter in
            var actual = NSRange(location: NSNotFound, length: 0)
            let rect = adapter.firstRectForInput(range: range, actualRange: &actual)
            return actual.location == NSNotFound ? nil : (rect, actual)
        }
        guard let result = result else { return .zero }
        actualRange?.pointee = result.1
        return result.0
    }
    func characterIndex(for point: NSPoint) -> Int {
        owner?.query(NSNotFound) { $0.characterIndexForInput(point: point) } ?? NSNotFound
    }
}

private final class AppKitPreparedDriver: PreparedInputContextConnection.Driver {
    private let context: NSTextInputContext
    init(client: NSTextInputClient) { context = NSTextInputContext(client: client) }
    var associationTarget: NSObject { context }
    func activate() { context.activate() }
    func handle(_ event: NSEvent) -> Bool { context.handleEvent(event) }
    func invalidateCoordinates() { context.invalidateCharacterCoordinates() }
    func discardMarkedText() { context.discardMarkedText() }
    func deactivate() { context.deactivate() }
}
#endif
