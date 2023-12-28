struct PropertyChangeId: Hashable {
    private let observableId: ObservableId
    private let changeType: PropertyChangeType
    private let keyPath: String

    init<T: Observable, U>(
        for observable: T,
        publishing changeType: PropertyChangeType,
        of keyPath: KeyPath<T, U>
    ) {
        self.observableId = ObservableId(observable)
        self.changeType = changeType
        self.keyPath = "\(keyPath)"
    }
}
