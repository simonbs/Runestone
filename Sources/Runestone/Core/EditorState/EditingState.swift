import Combine

final class EditorState {
    let isEditing = CurrentValueSubject<Bool, Never>(false)
    let isEditable = CurrentValueSubject<Bool, Never>(true)
    let isSelectable = CurrentValueSubject<Bool, Never>(true)

    private unowned let textView: TextView
    private let textViewDelegate: ErasedTextViewDelegate
    private var cancellables: Set<AnyCancellable> = []

    init(textView: TextView, textViewDelegate: ErasedTextViewDelegate) {
        self.textView = textView
        self.textViewDelegate = textViewDelegate
        Publishers.CombineLatest3(isEditing, isEditable, isSelectable).sink { [weak self] isEditing, isEditable, isSelectable in
            if isEditing && (!isEditing || !isSelectable) {
                self?.endEditing()
            }
        }.store(in: &cancellables)
    }
}

private extension EditorState {
    private func endEditing() {
        textView.resignFirstResponder()
        isEditing.value = false
        textViewDelegate.textViewDidEndEditing()
    }
}
