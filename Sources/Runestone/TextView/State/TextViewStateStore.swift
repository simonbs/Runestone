import _RunestoneObservation
import _RunestoneMultiPlatform
import Foundation

@RunestoneObservable
final class TextViewStateStore {
    var characterPairs: [CharacterPair] = []
    var characterPairTrailingComponentDeletionMode: CharacterPairTrailingComponentDeletionMode = .disabled
    var estimatedLineHeight: CGFloat = 20
    var indentStrategy: IndentStrategy = .tab(length: 4)
    var isLineWrappingEnabled = true
    var lineBreakMode: LineBreakMode = .byWordWrapping
    var lineEndings: LineEnding = .lf
    var lineHeightMultiplier: Double = 1
    var markedRange: NSRange?
    var selectedRange = NSRange(location: 0, length: 0)
    var textContainerInset: MultiPlatformEdgeInsets = .zero
}

extension TextViewStateStore: CharacterPairsReadable {}
extension TextViewStateStore: EstimatedLineHeightReadable {}
extension TextViewStateStore: IndentStrategyReadable {}
extension TextViewStateStore: IsLineWrappingEnabledReadable {}
extension TextViewStateStore: LineBreakModeReadable {}
extension TextViewStateStore: LineEndingsReadable {}
extension TextViewStateStore: LineHeightMultiplierReadable {}
extension TextViewStateStore: MarkedRangeWritable {}
extension TextViewStateStore: SelectedRangeWritable {}
extension TextViewStateStore: TextContainerInsetReadable {}
