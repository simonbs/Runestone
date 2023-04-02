#if os(iOS)
import UIKit

final class EditMenuPresenter_iOS: EditMenuPresenter {
    private let sourceView: UIView
    private let editMenuController: EditMenuController

    init(sourceView: UIView, editMenuController: EditMenuController) {
        self.sourceView = sourceView
        self.editMenuController = editMenuController
    }

    func presentForText(in range: NSRange) {
        editMenuController.presentEditMenu(from: sourceView, forTextIn: range)
    }
}
#endif
