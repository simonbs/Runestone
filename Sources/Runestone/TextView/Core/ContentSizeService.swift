import Combine
import Foundation
import MultiPlatform
import LineManager

final class ContentSizeService {
    var safeAreaInset: MultiPlatformEdgeInsets = .zero
    var containerSize: CGSize = .zero {
        didSet {
            if containerSize != oldValue && isLineWrappingEnabled {
                invalidateContentSize()
            }
        }
    }
    var textContainerInset: MultiPlatformEdgeInsets = .zero
    var isLineWrappingEnabled = true {
        didSet {
            if isLineWrappingEnabled != oldValue {
                invalidateContentSize()
            }
        }
    }
    var horizontalOverscrollFactor: CGFloat = 0 {
        didSet {
            if horizontalOverscrollFactor != oldValue && !isLineWrappingEnabled {
                invalidateContentSize()
            }
        }
    }
    var verticalOverscrollFactor: CGFloat = 0 {
        didSet {
            if verticalOverscrollFactor != oldValue {
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
        let minimumWidth = containerSize.width - safeAreaInset.left - safeAreaInset.right
        if isLineWrappingEnabled {
            return minimumWidth
        } else {
            let textContentWidth = longestLineWidth ?? containerSize.width
            let preferredWidth = ceil(
                textContentWidth
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
        let horizontalOverscrollLength = max(containerSize.width * horizontalOverscrollFactor, 0)
        let verticalOverscrollLength = max(containerSize.height * verticalOverscrollFactor, 0)
        let width = contentWidth + (isLineWrappingEnabled ? 0 : horizontalOverscrollLength)
        let height = contentHeight + verticalOverscrollLength
        return CGSize(width: width, height: height)
    }
    @Published private(set) var isContentSizeInvalid = false

    private let lineControllerStorage: LineControllerStorage
    private let gutterWidthService: GutterWidthService
    private var lineIDTrackingWidth: LineNodeID?
    private var lineWidths: [LineNodeID: CGFloat] = [:]
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

    init(
        lineManager: LineManager,
        lineControllerStorage: LineControllerStorage,
        gutterWidthService: GutterWidthService,
        invisibleCharacterConfiguration: InvisibleCharacterConfiguration
    ) {
        self.lineManager = lineManager
        self.lineControllerStorage = lineControllerStorage
        self.gutterWidthService = gutterWidthService
        self.invisibleCharacterConfiguration = invisibleCharacterConfiguration
    }

    func invalidateContentSize() {
        _longestLineWidth = nil
        _totalLinesHeight = nil
    }

    func removeLine(withID lineID: LineNodeID) {
        lineWidths.removeValue(forKey: lineID)
        if lineID == lineIDTrackingWidth {
            lineIDTrackingWidth = nil
            _longestLineWidth = nil
        }
    }

    func setSize(of line: LineNode, to newSize: CGSize) {
        let lineWidth = newSize.width
        if lineWidths[line.id] != lineWidth {
            lineWidths[line.id] = lineWidth
            if let lineIDTrackingWidth = lineIDTrackingWidth {
                let maximumLineWidth = lineWidths[lineIDTrackingWidth] ?? 0
                if line.id == lineIDTrackingWidth || lineWidth > maximumLineWidth {
                    self.lineIDTrackingWidth = line.id
                    _longestLineWidth = nil
                    isContentSizeInvalid = true
                }
            } else if !isLineWrappingEnabled {
                _longestLineWidth = nil
                isContentSizeInvalid = true
            }
        }
        let didUpdateHeight = lineManager.setHeight(of: line, to: newSize.height)
        if didUpdateHeight {
            _totalLinesHeight = nil
            isContentSizeInvalid = true
        }
    }
}

private extension ContentSizeService {
    private func storeWidthOfInitiallyLongestLine() {
        guard let longestLine = lineManager.initialLongestLine else {
            return
        }
        lineIDTrackingWidth = longestLine.id
        let lineController = lineControllerStorage.getOrCreateLineController(for: longestLine)
        lineController.invalidateString()
        lineController.invalidateTypesetting()
        lineController.invalidateSyntaxHighlighting()
        lineWidths[longestLine.id] = lineController.lineWidth
        if !isLineWrappingEnabled {
            _longestLineWidth = nil
            isContentSizeInvalid = true
        }
    }
}
