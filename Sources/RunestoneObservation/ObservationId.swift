import Foundation

public struct ObservationId: Hashable {
    private let id: UUID

    init() {
        self.id = UUID()
    }
}
