enum TextDirection {
    case forward
    case backward

    var opposite: Self {
        switch self {
        case .forward:
            return .backward
        case .backward:
            return .forward
        }
    }
}
