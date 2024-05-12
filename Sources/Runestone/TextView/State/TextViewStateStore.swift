import _RunestoneObservation
import _RunestoneMultiPlatform
import Foundation

@RunestoneObservable @RunestoneObserver
final class TextViewStateStore {
    var characterPairs: [CharacterPair] = []
    var characterPairTrailingComponentDeletionMode: CharacterPairTrailingComponentDeletionMode = .disabled
    var estimatedCharacterWidth: CGFloat {
        ("8" as NSString).size(withAttributes: [.font: theme.font]).width
    }
    var estimatedLineHeight: CGFloat = 20
    var horizontalOverscrollFactor: CGFloat = 0
    var indentStrategy: IndentStrategy = .tab(length: 4)
    var insertionPointShape: InsertionPointShape = .verticalBar
    var isLineWrappingEnabled = true
    var kern: CGFloat = 0
    var lineBreakMode: LineBreakMode = .byWordWrapping
    var lineEndings: LineEnding = .lf
    var lineHeightMultiplier: Double = 1
    var markedRange: NSRange?
    var selectedRange = NSRange(location: 0, length: 0)
    var textContainerInset: MultiPlatformEdgeInsets = .zero
    var theme: Theme = DefaultTheme()
    var verticalOverscrollFactor: CGFloat = 0
    var showTabs = false
    var showSpaces = false
    var showNonBreakingSpaces = false
    var showLineBreaks = false
    var showSoftLineBreaks = false
    var tabSymbol = "\u{25b8}"
    var spaceSymbol = "\u{00b7}"
    var nonBreakingSpaceSymbol = "\u{00b7}"
    var lineBreakSymbol = "\u{00ac}"
    var softLineBreakSymbol = "\u{00ac}"
    var maximumLineBreakSymbolWidth: CGFloat {
        0
    }
}

extension TextViewStateStore: Equatable {
    static func == (lhs: TextViewStateStore, rhs: TextViewStateStore) -> Bool {
        lhs === rhs
    }
}

extension TextViewStateStore: CharacterPairsReadable {}
extension TextViewStateStore: EstimatedCharacterWidthReadable {}
extension TextViewStateStore: EstimatedLineHeightReadable {}
extension TextViewStateStore: IndentStrategyReadable {}
extension TextViewStateStore: InsertionPointShapeReadable {}
extension TextViewStateStore: InvisibleCharacterConfigurationReadable {}
extension TextViewStateStore: IsLineWrappingEnabledReadable {}
extension TextViewStateStore: KernReadable {}
extension TextViewStateStore: LineBreakModeReadable {}
extension TextViewStateStore: LineEndingsReadable {}
extension TextViewStateStore: LineHeightMultiplierReadable {}
extension TextViewStateStore: MarkedRangeWritable {}
extension TextViewStateStore: OverscrollFactorReadable {}
extension TextViewStateStore: SelectedRangeWritable {}
extension TextViewStateStore: TextContainerInsetReadable {}
extension TextViewStateStore: ThemeReadable {}
