import Foundation

protocol LineNavigationLocationFactory {
    func location(
        movingFrom sourceLocation: Int,
        byLineCount offset: Int,
        inDirection direction: TextDirection
    ) -> Int
    func reset()
}

extension LineNavigationLocationFactory {
    func reset() {}
}
