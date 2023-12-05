//import Combine
//
//final class EditorState {
//    let isEditing = CurrentValueSubject<Bool, Never>(false)
//    let isEditable = CurrentValueSubject<Bool, Never>(true)
//    let isSelectable = CurrentValueSubject<Bool, Never>(true)
//
//    private let proxyView: ProxyView
//    private let textViewDelegate: ErasedTextViewDelegate
//    private var cancellables: Set<AnyCancellable> = []
//
//    init(proxyView: ProxyView, textViewDelegate: ErasedTextViewDelegate) {
//        self.proxyView = proxyView
//        self.textViewDelegate = textViewDelegate
//        Publishers.CombineLatest3(isEditing, isEditable, isSelectable).sink { [weak self] isEditing, isEditable, isSelectable in
//            if isEditing && (!isEditing || !isSelectable) {
//                self?.endEditing()
//            }
//        }.store(in: &cancellables)
//    }
//}
//
//private extension EditorState {
//    private func endEditing() {
//        proxyView.view?.resignFirstResponder()
//        isEditing.value = false
//        textViewDelegate.textViewDidEndEditing()
//    }
//}
