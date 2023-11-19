protocol ObservableStore {
    var observationIds: [ObservationId] { get }
    func addObservable(_ observable: some Observable, for observationId: ObservationId)
    func removeObservable(for observationId: ObservationId)
    func observable(for observationId: ObservationId) -> (any Observable)?
    func removeAll()
}
