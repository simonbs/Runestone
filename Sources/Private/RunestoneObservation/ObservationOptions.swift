public struct ObservationOptions: OptionSet {
    public static let initialValue = ObservationOptions(rawValue: 1 << 0)

    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}
