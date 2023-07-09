import Foundation

/// Provides a peek into the underlying attributed string of a text view.
///
/// This can be used to show a preview of search results. There is no way to get an attributed string from a text view without using a `TextPreview`.
///
/// The range of the text view may be longer than the one passed to ``TextView/textPreview(containing:)`` when creating the preview. This is done to provide some context around the input range. Use ``TextPreview/needleInPreviewRange`` to shorten the preview and get the text in the exact input range if needed.
public final class TextPreview {
    /// The range passed to ``TextView/textPreview(containing:)`` when creating the preview.
    public let needleRange: NSRange
    /// The range of the attributed string relative to the text in the text view.
    ///
    /// The range may be longer than the one specified by ``TextPreview/needleRange``.
    public let previewRange: NSRange
    /// The range of the needle range local to the preview range.
    /// 
    /// This range is guaranteed to be within the ``TextPreview/previewRange``.
    public let needleInPreviewRange: NSRange
    /// The attributed string within the preview range.
    ///
    /// The string is not available until after calling ``TextPreview/prepare()`` on the text preview. Preparing the preview is potentially an expensive operation and should ideally be done on-demand.
    public private(set) var attributedString: NSAttributedString?

    private let lineControllers: [LineController]

    init(needleRange: NSRange, previewRange: NSRange, needleInPreviewRange: NSRange, lineControllers: [LineController]) {
        self.needleRange = needleRange
        self.previewRange = previewRange
        self.needleInPreviewRange = needleInPreviewRange
        self.lineControllers = lineControllers
    }

    /// Assigns a value to the attributed string.
    ///
    /// This is potentially an expensive operation and should ideally be done on-demand.
    public func prepare() {
        let resultingAttributedString = NSMutableAttributedString()
        var remainingLength = previewRange.length
        for lineController in lineControllers {
            let lineLocation = lineController.line.location
            let lineLength = lineController.line.data.totalLength
            let location = max(previewRange.location - lineLocation, 0)
            let length = min(remainingLength, lineLength)
            let range = NSRange(location: location, length: length)
            lineController.prepareToDisplayString(toLocation: range.upperBound, syntaxHighlightAsynchronously: false)
            if let attributedString = lineController.attributedString {
                let substring = attributedString.attributedSubstring(from: range)
                resultingAttributedString.append(substring)
                remainingLength -= range.length
            }
        }
        attributedString = resultingAttributedString
    }

    /// Invalidate the syntax highlighted attributed string.
    ///
    /// Calling this will invalidate the appearance of the attributed string and subsequent calls to ``TextPreview/prepare()`` will create an attributed string with updated appearance.
    ///
    /// This may be called to update the attributed string when it is known that the appearance have changed and the text preview must be updated. For example, when adjusting the kerning of the text in the text view.
    public func invalidateSyntaxHighlighting() {
        for lineController in lineControllers {
            lineController.invalidateSyntaxHighlighting()
        }
    }

    /// Cancels syntax highlighting the text in the text preview.
    ///
    /// Call this when the preview should no longer be shown. For example, if showing the text preview in a collection view cell or table view cell, you may call this when the cell disappears from the screen.
    public func cancelSyntaxHighlighting() {
        for lineController in lineControllers {
            lineController.cancelSyntaxHighlighting()
        }
    }
}
