#if canImport(AppKit)
import AppKit

/// A document-owned lifetime sentinel for future prepared input integration.
///
/// The document must be the only owner of this object. The framework retains it
/// only weakly. When the document is destroyed, or the document calls
/// `invalidate()`, every still-registered input view is immediately and
/// permanently quarantined; deferred AppKit cleanup runs on the main thread.
/// This sentinel does not attach a client or create an editable responder.
public final class RunestoneInputDocumentLifetime {
    final class Registration {
        fileprivate weak var view: ReadOnlyDocumentView?
        fileprivate weak var connection: PreparedInputContextConnection?
        fileprivate init(view: ReadOnlyDocumentView) { self.view = view }
    }

    private let lock = NSLock()
    private var invalidated = false
    private var registrations: [ObjectIdentifier: Registration] = [:]

    public init() {}

    /// Invalidates once, from any thread. Views immediately stop exposing
    /// input and content without calling into AppKit on the calling stack.
    /// A view cannot be reused after it is quarantined.
    public func invalidate() {
        lock.lock()
        guard !invalidated else { lock.unlock(); return }
        invalidated = true
        quarantineRegistrationsWhileLocked()
        lock.unlock()
    }

    /// The caller retains only the token, never this sentinel. Registration and
    /// invalidation are serialized: once invalidation wins no view can attach.
    func register(_ view: ReadOnlyDocumentView) -> Registration? {
        lock.lock()
        defer { lock.unlock() }
        guard !invalidated else { return nil }
        let registration = Registration(view: view)
        registrations[ObjectIdentifier(registration)] = registration
        return registration
    }

    /// Bind before exposing the attachment. Invalidation either observes the
    /// connection or causes binding to fail; it cannot slip between the two.
    func bind(_ connection: PreparedInputContextConnection, to registration: Registration) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !invalidated, registrations[ObjectIdentifier(registration)] === registration else { return false }
        registration.connection = connection
        return true
    }

    /// Stop tracking only this exact registration after a clean disconnect.
    func unregister(_ registration: Registration) {
        lock.lock()
        defer { lock.unlock() }
        let id = ObjectIdentifier(registration)
        if registrations[id] === registration { registrations.removeValue(forKey: id) }
    }

    // Called with the lock held. The queued block waits for this method to
    // return and for invalidate to unlock. Consequently, all temporary strong
    // references acquired here are released before the block can release the
    // captured views on main, even if main drains while invalidate is running.
    private func quarantineRegistrationsWhileLocked() {
        let views = registrations.values.compactMap(\.view)
        let connections = registrations.values.compactMap(\.connection)
        registrations.removeAll()
        for view in views { view.quarantineInputViewWithoutCallouts() }
        guard !views.isEmpty || !connections.isEmpty else { return }
        let lock = lock
        DispatchQueue.main.async {
            lock.lock()
            lock.unlock()
            connections.forEach { $0.abandonDocument() }
            withExtendedLifetime(views) {}
        }
    }

    deinit { invalidate() }
}
#endif
