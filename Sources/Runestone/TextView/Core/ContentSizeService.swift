import Combine
import UIKit

final class ContentSizeService {
    var safeAreaInset: UIEdgeInsets = .zero
    var textContainerInset: UIEdgeInsets = .zero
    var scrollViewWidth: CGFloat = 0 {
        didSet {
            if scrollViewWidth != oldValue && isLineWrappingEnabled {
                invalidateContentSize()
            }
        }
    }
    var isLineWrappingEnabled = true {
        didSet {
            if isLineWrappingEnabled != oldValue {
                invalidateContentSize()
            }
        }
    }
    let invisibleCharacterConfiguration: InvisibleCharacterConfiguration
    var lineManager: LineManager {
        didSet {
            if lineManager !== oldValue {
                lineWidths = [:]
                invalidateContentSize()
                storeWidthOfInitiallyLongestLine()
            }
        }
    }
    var contentWidth: CGFloat {
        let minimumWidth = scrollViewWidth - safeAreaInset.left - safeAreaInset.right
        if isLineWrappingEnabled {
            return minimumWidth
        } else {
            let textContentWidth = longestLineWidth ?? scrollViewWidth
            let preferredWidth = ceil(
                textContentWidth
                + gutterWidthService.gutterWidth
                + textContainerInset.left
                + textContainerInset.right
                + invisibleCharacterConfiguration.maximumLineBreakSymbolWidth
            )
            return max(preferredWidth, minimumWidth)
        }
    }
    var contentHeight: CGFloat {
        ceil(totalLinesHeight + textContainerInset.top + textContainerInset.bottom)
    }
    var contentSize: CGSize {
        CGSize(width: contentWidth, height: contentHeight)
    }
    @Published private(set) var isContentSizeInvalid = false

    private let lineControllerStorage: LineControllerStorage
    private let gutterWidthService: GutterWidthService
    private var lineIDTrackingWidth: DocumentLineNodeID?
    private var lineWidths: [DocumentLineNodeID: CGFloat] = [:]
    private var longestLineWidth: CGFloat? {
        if let longestLineWidth = _longestLineWidth {
            return longestLineWidth
        } else if let lineIDTrackingWidth = lineIDTrackingWidth, let lineWidth = lineWidths[lineIDTrackingWidth] {
            let longestLineWidth = lineWidth
            _longestLineWidth = longestLineWidth
            if _totalLinesHeight != nil {
                isContentSizeInvalid = false
            }
            return longestLineWidth
        } else {
            lineIDTrackingWidth = nil
            var longestLineWidth: CGFloat?
            for (lineID, lineWidth) in lineWidths {
                if let currentLongestLineWidth = longestLineWidth {
                    if lineWidth > currentLongestLineWidth {
                        lineIDTrackingWidth = lineID
                        longestLineWidth = lineWidth
                    }
                } else {
                    lineIDTrackingWidth = lineID
                    longestLineWidth = lineWidth
                }
            }
            _longestLineWidth = longestLineWidth
            if longestLineWidth != nil && _totalLinesHeight != nil {
                isContentSizeInvalid = false
            }
            return longestLineWidth
        }
    }
    private var totalLinesHeight: CGFloat {
        if let totalLinesHeight = _totalLinesHeight {
            return totalLinesHeight
        } else {
            let totalLinesHeight = lineManager.contentHeight
            _totalLinesHeight = totalLinesHeight
            if _longestLineWidth != nil {
                isContentSizeInvalid = false
            }
            return totalLinesHeight
        }
    }
    private var _longestLineWidth: CGFloat? {
        didSet {
            if _longestLineWidth != oldValue {
                isContentSizeInvalid = _totalLinesHeight == nil || _longestLineWidth == nil
            }
        }
    }
    private var _totalLinesHeight: CGFloat? {
        didSet {
            if _totalLinesHeight != oldValue {
                isContentSizeInvalid = _totalLinesHeight == nil || _longestLineWidth == nil
            }
        }
    }

    init(lineManager: LineManager,
         lineControllerStorage: LineControllerStorage,
         gutterWidthService: GutterWidthService,
         invisibleCharacterConfiguration: InvisibleCharacterConfiguration) {
        self.lineManager = lineManager
        self.lineControllerStorage = lineControllerStorage
        self.gutterWidthService = gutterWidthService
        self.invisibleCharacterConfiguration = invisibleCharacterConfiguration
    }

    func invalidateContentSize() {
        _longestLineWidth = nil
        _totalLinesHeight = nil
    }

    func removeLine(withID lineID: DocumentLineNodeID) {
        lineWidths.removeValue(forKey: lineID)
        if lineID == lineIDTrackingWidth {
            lineIDTrackingWidth = nil
            _longestLineWidth = nil
        }
    }

    func setSize(of line: DocumentLineNode, to newSize: CGSize) {
        let lineWidth = newSize.width
        if lineWidths[line.id] != lineWidth {
            lineWidths[line.id] = lineWidth
            if let lineIDTrackingWidth = lineIDTrackingWidth {
                let maximumLineWidth = lineWidths[lineIDTrackingWidth] ?? 0
                if line.id == lineIDTrackingWidth || lineWidth > maximumLineWidth {
                    self.lineIDTrackingWidth = line.id
                    _longestLineWidth = nil
                }
            } else if !isLineWrappingEnabled {
                _longestLineWidth = nil
            }
        }
        let didUpdateHeight = lineManager.setHeight(of: line, to: newSize.height)
        if didUpdateHeight {
            _totalLinesHeight = nil
        }
    }
}

private extension ContentSizeService {
    private func storeWidthOfInitiallyLongestLine() {
        if let longestLine = lineManager.initialLongestLine {
            lineIDTrackingWidth = longestLine.id
            let lineController = lineControllerStorage.getOrCreateLineController(for: longestLine)
            lineController.invalidateEverything()
            lineWidths[longestLine.id] = lineController.lineWidth
            if !isLineWrappingEnabled {
                _longestLineWidth = nil
            }
        }
    }
}
