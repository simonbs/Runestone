#if canImport(AppKit)
import AppKit
@testable import RunestoneAppKit
import XCTest

final class DocumentInputRetirementTests: XCTestCase {
    private enum RetirementPoint: CaseIterable {
        case layout, finish, notification
    }

    func testPublishedEditReconcilesRetirementAtEachCallbackBoundary() throws {
        for point in RetirementPoint.allCases {
            try checkRetirement(at: point)
        }
    }

    private func checkRetirement(at point: RetirementPoint) throws {
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 14)]
        let original = String(repeating: "line\n", count: 100)
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: original, attributes: attributes))
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 180, height: 80))
        scroll.documentView = view
        scroll.tile()
        view.updateViewport()
        let permit = try XCTUnwrap(view.claimInputMutation())
        let document = RetirementTestDocument(text: original)
        var finishes = 0
        var notifications = 0
        var reconciliations: [DocumentInputSession.PublicationConflictPhase] = []
        var callbackSnapshot: NSAttributedString?
        var retiredAtLayout = false

        let session = DocumentInputSession(view: view, mutationPermit: permit, prepareChange: { candidate in
            let accepted = candidate.string
            return .init(publish: {
                document.text = accepted
                document.revision = UUID()
            }, finish: {
                finishes += 1
                XCTAssertEqual(document.text, "short")
                document.registerUndo(restoring: original)
                if point == .finish { view.retireInputView() }
            }, reconcile: { phase in
                reconciliations.append(phase)
                XCTAssertTrue(view.isRetired)
                XCTAssertEqual(document.text, "short")
                if phase == .beforeFinish { document.registerUndo(restoring: original) }
            })
        }, initialDocumentRevision: document.revision, documentRevision: { document.revision })
        session.contentDidChange = { snapshot in
            notifications += 1
            callbackSnapshot = snapshot
            XCTAssertEqual(snapshot.string, "short")
            if point == .notification {
                view.retireInputView()
                // Retiring the surface must not invalidate the already-delivered snapshot.
                XCTAssertEqual(snapshot.string, "short")
            }
        }

        view.postsFrameChangedNotifications = true
        let observer = NotificationCenter.default.addObserver(forName: NSView.frameDidChangeNotification,
                                                               object: view, queue: nil) { _ in
            guard point == .layout, !retiredAtLayout else { return }
            retiredAtLayout = true
            XCTAssertEqual(document.text, "short")
            XCTAssertEqual(view.content.string, "short")
            view.retireInputView()
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        XCTAssertTrue(session.insertText("short", replacementRange: NSRange(location: 0, length: original.utf16.count),
                                         attributes: attributes))
        XCTAssertTrue(view.isRetired, "Retirement hook was not reached at \(point)")
        XCTAssertEqual(document.text, "short")
        XCTAssertEqual(view.content.string, "")
        switch point {
        case .layout:
            XCTAssertTrue(retiredAtLayout)
            XCTAssertEqual(reconciliations, [.beforeFinish])
            XCTAssertEqual(finishes, 0)
            XCTAssertEqual(notifications, 0)
            XCTAssertNil(callbackSnapshot)
        case .finish:
            XCTAssertEqual(reconciliations, [.afterFinish])
            XCTAssertEqual(finishes, 1)
            XCTAssertEqual(notifications, 0)
            XCTAssertNil(callbackSnapshot)
        case .notification:
            XCTAssertEqual(reconciliations, [.afterNotification])
            XCTAssertEqual(finishes, 1)
            XCTAssertEqual(notifications, 1)
            XCTAssertEqual(callbackSnapshot?.string, "short")
        }
        XCTAssertFalse(session.insertText("later", replacementRange: NSRange(location: NSNotFound, length: 0),
                                          attributes: attributes))
        XCTAssertEqual(document.text, "short")
        XCTAssertEqual(document.undoRegistrations, 1)
        XCTAssertEqual(document.undo.groupingLevel, 0)
        XCTAssertTrue(document.undo.canUndo)
        document.undo.undo()
        XCTAssertEqual(document.text, original)
        XCTAssertFalse(document.undo.canUndo)
    }
}

private final class RetirementTestDocument: NSObject {
    var text: String
    var revision = UUID()
    let undo = UndoManager()
    private(set) var undoRegistrations = 0

    init(text: String) {
        self.text = text
        super.init()
        undo.groupsByEvent = false
    }

    func registerUndo(restoring previous: String) {
        undoRegistrations += 1
        undo.beginUndoGrouping()
        undo.registerUndo(withTarget: self) { target in
            target.text = previous
            target.revision = UUID()
        }
        undo.endUndoGrouping()
    }
}
#endif
