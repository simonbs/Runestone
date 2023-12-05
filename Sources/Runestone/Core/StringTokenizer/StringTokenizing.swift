import Foundation

protocol StringTokenizing {
    func isLocation(
        _ location: Int,
        atBoundary boundary: TextBoundary,
        inDirection direction: TextDirection
    ) -> Bool
    func location(
        from location: Int,
        toBoundary boundary: TextBoundary,
        inDirection direction: TextDirection
    ) -> Int?
}
