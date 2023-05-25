#if os(iOS)
import Combine
import UIKit

final class EditMenuPresenter_iOS: EditMenuPresenter {
    private let referenceView: CurrentValueSubject<WeakBox<TextView>, Never>
    private let editMenuController: EditMenuController

    init(referenceView: CurrentValueSubject<WeakBox<TextView>, Never>, editMenuController: EditMenuController) {
        self.referenceView = referenceView
        self.editMenuController = editMenuController
    }

    func presentForText(in range: NSRange) {
        if let referenceView = referenceView.value.value {
            editMenuController.presentEditMenu(from: referenceView, forTextIn: range)
        }
    }
}
#endif
