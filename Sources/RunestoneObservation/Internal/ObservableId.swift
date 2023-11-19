struct ObservableId: Hashable {
    private let id: ObjectIdentifier

    init<T: Observable>(_ observable: T) {
        self.id = ObjectIdentifier(observable)
    }
}
