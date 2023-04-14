import CoreText
import Foundation

extension CTFont {
    var familyName: String? {
        CTFontCopyName(self, kCTFontFamilyNameKey) as? String
    }
}
