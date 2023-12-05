import Foundation

struct CompositeEditingStateChangeHandler: EditingStateChangeHandler {
    private let editingStateChangeHandlers: [EditingStateChangeHandler]

    init(_ editingStateChangeHandlers: [EditingStateChangeHandler]) {
        self.editingStateChangeHandlers = editingStateChangeHandlers
    }

    func willBeginEditing() {
        for editingStateChangeHandler in editingStateChangeHandlers {
            editingStateChangeHandler.willBeginEditing()
        }
    }

    func didBeginEditing() {
        for editingStateChangeHandler in editingStateChangeHandlers {
            editingStateChangeHandler.didBeginEditing()
        }
    }

    func didCancelBeginEditing() {
        for editingStateChangeHandler in editingStateChangeHandlers {
            editingStateChangeHandler.didCancelBeginEditing()
        }
    }

    func didEndEditing() {
        for editingStateChangeHandler in editingStateChangeHandlers {
            editingStateChangeHandler.didEndEditing()
        }
    }
}
