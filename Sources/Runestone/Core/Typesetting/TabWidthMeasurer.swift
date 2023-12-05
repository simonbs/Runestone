import _RunestoneMultiPlatform
import Foundation
#if os(iOS)
import UIKit
#endif

enum TabWidthMeasurer {
    #if os(macOS)
    private typealias NSStringDrawingOptions = NSString.DrawingOptions
    #endif

    static func measure(lengthInSpaces: Int, font: MultiPlatformFont) -> CGFloat {
        let str = String(repeating: " ", count: lengthInSpaces)
        let maxSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        let options: NSStringDrawingOptions = [.usesFontLeading, .usesLineFragmentOrigin]
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let bounds = str.boundingRect(with: maxSize, options: options, attributes: attributes, context: nil)
        return round(bounds.size.width)
    }
}
