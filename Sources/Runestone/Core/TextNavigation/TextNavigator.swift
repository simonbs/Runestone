import Foundation

struct TextNavigator {
    typealias State = SelectedRangeWritable

    let state: State
    let locationProvider: TextNavigationLocationProviding

    func move(inDirection direction: TextNavigationDirection) {
        let sourceLocation = state.selectedRange.location
        guard let destinationLcation = locationProvider.location(
            from: sourceLocation,
            inDirection: direction,
            offset: 1
        ) else {
            return
        }
        state.selectedRange.location = destinationLcation
    }
}
