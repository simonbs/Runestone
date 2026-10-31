#if canImport(AppKit)
import Foundation

/// Internal document-scoped coordination for prepared input connections.
/// The document owns the registrations' lifetimes and gate. This object does
/// not create an editable responder or own any input connection.
/// All calls and scheduler work must run on the main thread. The scheduler must
/// enqueue asynchronously without running a nested event loop.
final class PreparedInputViewSynchronizer {
    final class Registration {
        fileprivate weak var connection: PreparedInputContextConnection?
        fileprivate init(_ connection: PreparedInputContextConnection) { self.connection = connection }
    }

    private var registrations: [ObjectIdentifier: Registration] = [:]
    private let schedule: (@escaping () -> Void) -> Void
    private var wakeScheduled = false

    init(schedule: @escaping (@escaping () -> Void) -> Void = { DispatchQueue.main.async(execute: $0) }) {
        self.schedule = schedule
    }

    /// The document retains the returned identity until that view is removed.
    @discardableResult
    func register(_ connection: PreparedInputContextConnection) -> Registration {
        precondition(Thread.isMainThread)
        for registration in registrations.values where registration.connection === connection {
            return registration
        }
        let registration = Registration(connection)
        registrations[ObjectIdentifier(registration)] = registration
        return registration
    }

    func unregister(_ registration: Registration) {
        precondition(Thread.isMainThread)
        let id = ObjectIdentifier(registration)
        if registrations[id] === registration { registrations.removeValue(forKey: id) }
    }

    /// Call after canonical publication, outside its no-callout phase. Exclude
    /// only the origin of an accepted, current edit. Reads, undo, and conflict
    /// reconciliation invalidate every view. Revision checks and the document
    /// gate must also reject stale callbacks before this notification is sent.
    func canonicalDidChange(excluding origin: Registration? = nil) {
        precondition(Thread.isMainThread)
        for registration in Array(registrations.values) {
            let id = ObjectIdentifier(registration)
            guard registrations[id] === registration else { continue }
            guard let connection = registration.connection else {
                registrations.removeValue(forKey: id)
                continue
            }
            if registration !== origin { connection.requestReset() }
        }
    }

    /// Notify after the document gate actually becomes available. A busy retry
    /// waits for a later release notification; a main-queue turn is not itself
    /// proof of input or document quiescence. Multiple releases may coalesce.
    func documentGateDidBecomeAvailable() {
        precondition(Thread.isMainThread)
        guard !wakeScheduled else { return }
        wakeScheduled = true
        schedule { [weak self] in
            guard let self = self else { return }
            self.wakeScheduled = false
            for registration in Array(self.registrations.values) {
                let id = ObjectIdentifier(registration)
                guard self.registrations[id] === registration else { continue }
                guard let connection = registration.connection else {
                    self.registrations.removeValue(forKey: id)
                    continue
                }
                connection.resumeAfterQuiescing()
            }
        }
    }
}
#endif
