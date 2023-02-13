import Foundation

extension CharacterSet {
    func containsAllCharacters(of string: String) -> Bool {
        var containsAllCharacters = true
        for char in string.unicodeScalars {
            if !contains(char) {
                containsAllCharacters = false
                break
            }
        }
        return containsAllCharacters
    }
}
