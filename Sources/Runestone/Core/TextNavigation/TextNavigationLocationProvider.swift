import Foundation

struct TextNavigationLocationProvider<
    StringViewType: StringView,
    LineManagerType: LineManaging
>: TextNavigationLocationProviding {
    let stringView: StringViewType
    let lineManager: LineManagerType

    private var lineNavigationLocationProvider: LineNavigationLocationProvider<StringViewType, LineManagerType> {
        LineNavigationLocationProvider(stringView: stringView, lineManager: lineManager)
    }

    func location(
        from sourceLocation: Int,
        inDirection direction: TextNavigationDirection,
        offset: Int
    ) -> Int? {
        switch direction {
        case .right:
            locationMovingRight(from: sourceLocation, offset: offset)
        case .left:
            locationMovingLeft(from: sourceLocation, offset: offset)
        case .up:
            lineNavigationLocationProvider.location(
                from: sourceLocation,
                inDirection: .up, 
                offset: offset
            )
        case .down:
            lineNavigationLocationProvider.location(
                from: sourceLocation,
                inDirection: .down,
                offset: offset
            )
        }
    }
}

private extension TextNavigationLocationProvider {
    private func locationMovingRight(from sourceLocation: Int, offset: Int) -> Int? {
        let destinationLocation = sourceLocation + offset
        guard destinationLocation <= stringView.length else {
            return nil
        }
        return destinationLocation
    }

    private func locationMovingLeft(from sourceLocation: Int, offset: Int) -> Int? {
        let destinationLocation = sourceLocation - offset
        guard destinationLocation >= 0 else {
            return nil
        }
        return destinationLocation
    }
}
