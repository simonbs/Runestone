import Foundation

package struct ObservationId: Hashable {
    private let id: UUID

    init() {
        self.id = UUID()
    }
}
