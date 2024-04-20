import Foundation

protocol CharacterBoundsProviding {
    func boundsOfCharacter(atLocation location: Int) -> CGRect?
}
