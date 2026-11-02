import Foundation

extension NSAttributedString {
    func isWhitespaceCharacter(at location: Int) -> Bool {
        guard location < length else {
            return false
        }
        let string = CFAttributedStringGetString(self)
        guard let scalar = UnicodeScalar(CFStringGetCharacterAtIndex(string, location)) else {
            return false
        }
        return CharacterSet.whitespaces.contains(scalar)
    }
}
