#if os(macOS)
import AppKit
#endif
import Combine
#if os(iOS)
import UIKit
#endif

final class PageGuideLayouter {
    #if os(macOS)
    private typealias NSStringDrawingOptions = NSString.DrawingOptions
    #endif

    var isEnabled = false {
        didSet {
            if isEnabled != oldValue {
//                if isEnabled {
//                    containerView.value.value?.addSubview(view)
//                } else {
//                    view.removeFromSuperview()
//                }
            }
        }
    }
    var column = 120 {
        didSet {
            if column != oldValue {
                updateColumnOffset()
            }
        }
    }

//    private let font: CurrentValueSubject<MultiPlatformFont, Never>
//    private let kern: CurrentValueSubject<CGFloat, Never>
//    private let backgroundColor: CurrentValueSubject<MultiPlatformColor, Never>
//    private let hairlineColor: CurrentValueSubject<MultiPlatformColor, Never>
//    private let hairlineWidth: CurrentValueSubject<CGFloat, Never>
//    private let containerView: CurrentValueSubject<WeakBox<TextView>, Never>
//    private var columnOffset: CGFloat = 0
//    private var cancellables: Set<AnyCancellable> = []
//    private let view = PageGuideView()
//
//    init(
//        font: CurrentValueSubject<MultiPlatformFont, Never>,
//        kern: CurrentValueSubject<CGFloat, Never>,
//        backgroundColor: CurrentValueSubject<MultiPlatformColor, Never>,
//        hairlineColor: CurrentValueSubject<MultiPlatformColor, Never>,
//        hairlineWidth: CurrentValueSubject<CGFloat, Never>,
//        containerView: CurrentValueSubject<WeakBox<TextView>, Never>
//    ) {
//        self.font = font
//        self.kern = kern
//        self.backgroundColor = backgroundColor
//        self.hairlineColor = hairlineColor
//        self.hairlineWidth = hairlineWidth
//        self.containerView = containerView
//        setupColumnOffsetInvalidationObserver()
//    }
}

private extension PageGuideLayouter {
    private func setupColumnOffsetInvalidationObserver() {
//        Publishers.CombineLatest(font.removeDuplicates(), kern.removeDuplicates()).sink { [weak self] _, _ in
//            self?.updateColumnOffset()
//        }.store(in: &cancellables)
    }

    private func updateColumnOffset() {
        // Measure the width of a single character and multiply it by the pageGuideColumn.
//        let maxSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
//        let options: NSStringDrawingOptions = [.usesFontLeading, .usesLineFragmentOrigin]
//        let attributes: [NSAttributedString.Key: Any] = [.font: font.value, .kern: kern.value]
//        let bounds = " ".boundingRect(with: maxSize, options: options, attributes: attributes, context: nil)
//        columnOffset = round(bounds.size.width * CGFloat(column))
    }
}
