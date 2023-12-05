package struct ObservationOptions: OptionSet {
    package static let initialValue = ObservationOptions(rawValue: 1 << 0)

    package let rawValue: Int

    package init(rawValue: Int) {
        self.rawValue = rawValue
    }
}
