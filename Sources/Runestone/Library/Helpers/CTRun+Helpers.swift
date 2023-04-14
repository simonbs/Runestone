import CoreText
import Foundation

extension CTRun {
    var font: CTFont? {
        guard let font = attributes[NSAttributedString.Key.font] else {
            return nil
        }
        return font as! CTFont?
    }
}

private extension CTRun {
    private var attributes: [NSAttributedString.Key: Any] {
        CTRunGetAttributes(self) as? [NSAttributedString.Key: Any] ?? [:]
    }
}
