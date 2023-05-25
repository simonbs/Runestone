import Foundation

final class TextEditState {
    var hasDeletedTextWithPendingLayoutSubviews = false
    var notifyDelegateAboutSelectionChangeInLayoutSubviews = false
    var notifyInputDelegateAboutSelectionChangeInLayoutSubviews = false
    var isRestoringPreviouslyDeletedText = false
}
