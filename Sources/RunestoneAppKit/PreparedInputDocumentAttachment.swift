#if canImport(AppKit)
import AppKit

/// Internal wiring for a document gate and one prepared input connection.
/// This is not a responder, and is deliberately unavailable to framework clients.
/// A host must own the document lifetime and notification bridge independently
/// of this attachment. The attachment and all operations run on the main thread.
final class PreparedInputDocumentAttachment {
    private final class Relay {
        weak var host: RunestoneInputDocumentHost?
        weak var bridge: RunestoneInputDocumentBridge?
        weak var lifetime: RunestoneInputDocumentLifetime?
        weak var connection: PreparedInputContextConnection?
        var registration: PreparedInputViewSynchronizer.Registration?
    }

    // Keep all AppKit-owning references in one transferable payload so an
    // off-main final release cannot destroy them on the releasing thread.
    private final class Payload {
        let view: ReadOnlyDocumentView
        let adapter: PreparedInputEventAdapter
        let connection: PreparedInputContextConnection
        let relay: Relay
        let lifetimeRegistration: RunestoneInputDocumentLifetime.Registration
        init(view: ReadOnlyDocumentView, adapter: PreparedInputEventAdapter,
             connection: PreparedInputContextConnection, relay: Relay,
             lifetimeRegistration: RunestoneInputDocumentLifetime.Registration) {
            self.view = view
            self.adapter = adapter
            self.connection = connection
            self.relay = relay
            self.lifetimeRegistration = lifetimeRegistration
        }
    }
    private var payload: Payload?
    var view: ReadOnlyDocumentView { payload!.view }
    var adapter: PreparedInputEventAdapter { payload!.adapter }
    var connection: PreparedInputContextConnection { payload!.connection }
    private var relay: Relay { payload!.relay }
    private var lifetimeRegistration: RunestoneInputDocumentLifetime.Registration { payload!.lifetimeRegistration }
    private var disconnected = false

    private init(view: ReadOnlyDocumentView, adapter: PreparedInputEventAdapter,
                 connection: PreparedInputContextConnection, relay: Relay,
                 lifetimeRegistration: RunestoneInputDocumentLifetime.Registration) {
        payload = Payload(view: view, adapter: adapter, connection: connection,
                          relay: relay, lifetimeRegistration: lifetimeRegistration)
    }

    /// Installs only a fresh, unexposed view while the document gate is held.
    /// A failed attachment never returns a view for reuse.
    static func attach(host: RunestoneInputDocumentHost, lifetime: RunestoneInputDocumentLifetime,
                       bridge: RunestoneInputDocumentBridge,
                       makeDriver: PreparedInputContextConnection.DriverFactory? = nil,
                       schedule: @escaping (@escaping () -> Void) -> Void = { DispatchQueue.main.async(execute: $0) }) -> PreparedInputDocumentAttachment? {
        precondition(Thread.isMainThread)
        guard bridge.bind(host: host, lifetime: lifetime) else { return nil }
        guard case let .reserved(initialLease) = host.beginInputReconstruction() else { return nil }
        var leaseOpen = true
        var registration: PreparedInputViewSynchronizer.Registration?
        defer {
            if leaseOpen {
                initialLease.close()
                bridge.synchronizer.documentGateDidBecomeAvailable(afterReconstructionBy: registration)
            }
        }
        let revision = initialLease.revision
        let snapshot = NSAttributedString(attributedString: initialLease.snapshot)
        guard host.inputRevision == revision else { return nil }
        let view = ReadOnlyDocumentView(content: snapshot)
        guard let lifetimeRegistration = lifetime.register(view) else {
            view.quarantineInputViewWithoutCallouts()
            return nil
        }
        var attached = false
        defer {
            if !attached {
                view.quarantineInputViewWithoutCallouts()
                lifetime.unregister(lifetimeRegistration)
            }
        }
        let relay = Relay()
        relay.host = host
        relay.bridge = bridge
        relay.lifetime = lifetime
        guard let adapter = PreparedInputEventAdapter(view: view, snapshot: snapshot, initialRevision: revision,
            documentRevision: { [weak relay, weak view] in
                guard let relay = relay, let view = view, !view.isRetired,
                      relay.lifetime != nil, relay.bridge != nil, let host = relay.host else { return nil }
                return host.inputRevision
            }, typingAttributes: { [weak relay, weak view] in
                guard let relay = relay, let view = view, !view.isRetired,
                      relay.lifetime != nil, relay.bridge != nil, let host = relay.host else { return [:] }
                return host.typingAttributes(for: view)
            }, beginEvent: { [weak relay, weak view] expected in
                guard let relay = relay, let view = view, !view.isRetired,
                      relay.lifetime != nil, let bridge = relay.bridge, let host = relay.host else { return .stale }
                switch host.beginInputEvent(expectedRevision: expected, source: view) {
                case .stale: return .stale
                case .busy: return .busy
                case let .reserved(lease):
                    return .reserved(.init(prepare: { [weak relay, weak view] candidate in
                        guard let publication = lease.prepare(candidate: candidate) else { return nil }
                        var publishedRevision: UUID?
                        return .init(publish: {
                            publication.publish()
                            publishedRevision = host.inputRevision
                        }, finish: { [weak relay, weak view] in
                            publication.finish()
                            let origin: PreparedInputViewSynchronizer.Registration?
                            if let relay = relay, let view = view, !view.isRetired,
                               let publishedRevision = publishedRevision, host.inputRevision == publishedRevision {
                                origin = relay.registration
                            } else { origin = nil }
                            bridge.synchronizer.canonicalDidChange(excluding: origin)
                        }, reconcile: { phase in
                            switch phase {
                            case .beforeFinish: publication.reconcile(.beforeFinish)
                            case .afterFinish: publication.reconcile(.afterFinish)
                            case .afterNotification: publication.reconcile(.afterNotification)
                            }
                            bridge.synchronizer.canonicalDidChange()
                        })
                    }, close: {
                        lease.close()
                        bridge.synchronizer.documentGateDidBecomeAvailable()
                        withExtendedLifetime(host) {}
                    }))
                }
            }, beginReconstruction: { [weak relay, weak view] in
                guard let relay = relay, let view = view, !view.isRetired,
                      relay.lifetime != nil, let bridge = relay.bridge, let host = relay.host else { return .busy }
                guard case let .reserved(lease) = host.beginInputReconstruction() else { return .busy }
                return .reserved(.init(snapshot: lease.snapshot, revision: lease.revision, close: { [weak relay] in
                    lease.close()
                    bridge.synchronizer.documentGateDidBecomeAvailable(afterReconstructionBy: relay?.registration)
                    withExtendedLifetime(host) {}
                }))
            }, requestReset: { [weak relay] in relay?.connection?.requestReset() }, schedule: schedule) else { return nil }
        guard let connection = PreparedInputContextConnection(adapter: adapter, view: view,
                                                               makeDriver: makeDriver, schedule: schedule) else { return nil }
        relay.connection = connection
        guard lifetime.bind(connection, to: lifetimeRegistration) else {
            connection.abandonDocument()
            return nil
        }
        registration = bridge.synchronizer.register(connection)
        relay.registration = registration
        initialLease.close()
        leaseOpen = false
        bridge.synchronizer.documentGateDidBecomeAvailable(afterReconstructionBy: registration)
        guard !view.isRetired, host.inputRevision == revision, view.content.isEqual(to: snapshot) else {
            connection.requestReset()
            return nil
        }
        attached = true
        return PreparedInputDocumentAttachment(view: view, adapter: adapter, connection: connection,
                                                relay: relay, lifetimeRegistration: lifetimeRegistration)
    }

    /// Retain this owner and retry after gate availability until this succeeds.
    @discardableResult
    func disconnect() -> Bool {
        precondition(Thread.isMainThread)
        if disconnected { return true }
        guard connection.disconnect() else { return false }
        if let registration = relay.registration { relay.bridge?.synchronizer.unregister(registration) }
        relay.lifetime?.unregister(lifetimeRegistration)
        disconnected = true
        return true
    }

    deinit {
        let gate = NSLock()
        gate.lock()
        transferCleanupToMain(gate: gate)
        gate.unlock()
    }

    private func transferCleanupToMain(gate: NSLock) {
        guard let payload = payload else { return }
        self.payload = nil
        if !disconnected { payload.view.quarantineInputViewWithoutCallouts() }
        DispatchQueue.main.async {
            gate.lock()
            gate.unlock()
            if let registration = payload.relay.registration {
                payload.relay.bridge?.synchronizer.unregister(registration)
            }
            payload.relay.lifetime?.unregister(payload.lifetimeRegistration)
            withExtendedLifetime(payload) {}
        }
    }

}
#endif
