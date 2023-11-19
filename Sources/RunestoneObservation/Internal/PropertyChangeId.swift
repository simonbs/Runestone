struct PropertyChangeId: Hashable {
    let observableId: ObservableId
    let changeType: PropertyChangeType
    let keyPath: AnyKeyPath

    init<T: Observable, U>(
        for observable: T,
        publishing changeType: PropertyChangeType,
        of keyPath: KeyPath<T, U>
    ) {
        self.observableId = ObservableId(observable)
        self.changeType = changeType
        self.keyPath = keyPath
    }
}
