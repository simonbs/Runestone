import _RunestoneObservation
import Foundation

@RunestoneObservable
final class TextViewStateStore {
    var characterPairs: [CharacterPair] = []
    var characterPairTrailingComponentDeletionMode: CharacterPairTrailingComponentDeletionMode = .disabled
    var estimatedLineHeight: CGFloat = 20
    var indentStrategy: IndentStrategy = .tab(length: 4)
    var lineEndings: LineEnding = .lf
    var markedRange: NSRange?
    var selectedRange = NSRange(location: 0, length: 0)
}

extension TextViewStateStore: CharacterPairsReadable {}
extension TextViewStateStore: EstimatedLineHeightReadable {}
extension TextViewStateStore: IndentStrategyReadable {}
extension TextViewStateStore: LineEndingsReadable {}
extension TextViewStateStore: MarkedRangeWritable {}
extension TextViewStateStore: SelectedRangeWritable {}
