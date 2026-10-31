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
    private var wakeRunning = false
    private var wakeRoundOpen = false
    private var wakeRoundExternal = false
    private var anotherExternalRound = false
    private var visited: Set<ObjectIdentifier> = []

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

    /// Call after each actual gate release. Pass the registration only for a
    /// reconstruction lease; ordinary edits and external operations use nil.
    /// A reconstruction release wakes other views, but must not wake itself.
    /// One release round visits each view at most once, so failing views cannot
    /// keep one another retrying solely by releasing their own leases.
    func documentGateDidBecomeAvailable(afterReconstructionBy origin: Registration? = nil) {
        precondition(Thread.isMainThread)
        if !wakeRoundOpen {
            wakeRoundOpen = true
            wakeRoundExternal = origin == nil
            visited.removeAll()
            if let origin = origin { visited.insert(ObjectIdentifier(origin)) }
        } else if origin == nil {
            // A genuinely new external release must survive an in-flight round.
            anotherExternalRound = true
        } else if !wakeRoundExternal, let origin = origin {
            visited.insert(ObjectIdentifier(origin))
        }
        scheduleWakeIfNeeded()
    }

    private func scheduleWakeIfNeeded() {
        guard wakeRoundOpen, !wakeRunning, !wakeScheduled else { return }
        wakeScheduled = true
        schedule { [weak self] in self?.runWakeRound() }
    }

    private func runWakeRound() {
        precondition(Thread.isMainThread)
        guard wakeRoundOpen, !wakeRunning else { return }
        wakeScheduled = false
        wakeRunning = true
        for registration in Array(registrations.values) {
            let id = ObjectIdentifier(registration)
            guard registrations[id] === registration, !visited.contains(id) else { continue }
            visited.insert(id)
            guard let connection = registration.connection else {
                registrations.removeValue(forKey: id)
                continue
            }
            connection.documentGateDidBecomeAvailable()
        }
        wakeRunning = false
        wakeRoundOpen = false
        visited.removeAll()
        if anotherExternalRound {
            anotherExternalRound = false
            wakeRoundOpen = true
            wakeRoundExternal = true
            scheduleWakeIfNeeded()
        }
    }
}
#endif
