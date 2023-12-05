//import Combine
//import CoreGraphics
//
//final class TextViewNeedsLayoutObserver<StringViewType: StringView> {
//    private let proxyView: ProxyView
//    private let stringView: StringViewType
//    private let viewport: CurrentValueSubject<CGRect, Never>
//    private var cancellables: Set<AnyCancellable> = []
//
//    init(
//        proxyView: ProxyView,
//        stringView: StringViewType,
//        viewport: CurrentValueSubject<CGRect, Never>
//    ) {
//        self.proxyView = proxyView
//        self.stringView = stringView
//        self.viewport = viewport
//        setupObserver()
//    }
//}
//
//private extension TextViewNeedsLayoutObserver {
//    private func setupObserver() {
////        Publishers.CombineLatest(stringView, viewport.removeDuplicates()).sink { [weak self] _ in
////            self?.textView.value.value?.setNeedsLayout()
////        }.store(in: &cancellables)
//        viewport.removeDuplicates().sink { [weak self] _ in
//            self?.proxyView.view?.setNeedsLayout()
//        }.store(in: &cancellables)
//    }
//}
