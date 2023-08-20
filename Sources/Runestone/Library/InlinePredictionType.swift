import UIKit

enum TextInlinePredictionType {
    case `default`
    case no
    case yes
}

@available(iOS 17, *)
extension UITextInlinePredictionType {
    init(_ textInlinePredictionType: TextInlinePredictionType) {
        switch textInlinePredictionType {
        case .default:
            self = .default
        case .no:
            self = .no
        case .yes:
            self = .yes
        }
    }
}

@available(iOS 17, *)
extension TextInlinePredictionType {
    init(_ textInlinePredictionType: UITextInlinePredictionType) {
        switch textInlinePredictionType {
        case .default:
            self = .default
        case .no:
            self = .no
        case .yes:
            self = .yes
        @unknown default:
            self = .default
        }
    }
}
