import Foundation

package enum TreeSitterTextPredicate {
    package struct CaptureEqualsStringParameters {
        let captureIndex: UInt32
        let string: String
        let isPositive: Bool

        init(captureIndex: UInt32, string: String, isPositive: Bool) {
            self.captureIndex = captureIndex
            self.string = string
            self.isPositive = isPositive
        }
    }

    package struct CaptureEqualsCaptureParameters {
        let lhsCaptureIndex: UInt32
        let rhsCaptureIndex: UInt32
        let isPositive: Bool

        init(lhsCaptureIndex: UInt32, rhsCaptureIndex: UInt32, isPositive: Bool) {
            self.lhsCaptureIndex = lhsCaptureIndex
            self.rhsCaptureIndex = rhsCaptureIndex
            self.isPositive = isPositive
        }
    }

    package struct CaptureMatchesPatternParameters {
        let captureIndex: UInt32
        let pattern: String
        let isPositive: Bool

        init(captureIndex: UInt32, pattern: String, isPositive: Bool) {
            self.captureIndex = captureIndex
            self.pattern = pattern
            self.isPositive = isPositive
        }
    }

    package struct UnsupportedParameters {
        let name: String

        init(name: String) {
            self.name = name
        }
    }

    case captureEqualsString(CaptureEqualsStringParameters)
    case captureEqualsCapture(CaptureEqualsCaptureParameters)
    case captureMatchesPattern(CaptureMatchesPatternParameters)
    case unsupported(UnsupportedParameters)
}

extension TreeSitterTextPredicate.CaptureEqualsStringParameters: CustomDebugStringConvertible {
    package var debugDescription: String {
        "[TreeSitterTextPredicate.CaptureEqualsStringParameters"
        + " captureIndex=\(captureIndex)"
        + " string=\(string)"
        + " isPositive=\(isPositive)"
        + "]"
    }
}

extension TreeSitterTextPredicate.CaptureEqualsCaptureParameters: CustomDebugStringConvertible {
    package var debugDescription: String {
        "[TreeSitterTextPredicate.CaptureEqualsCaptureParameters"
        + " lhsCaptureIndex=\(lhsCaptureIndex)"
        + " rhsCaptureIndex=\(rhsCaptureIndex)"
        + " isPositive=\(isPositive)"
        + "]"
    }
}

extension TreeSitterTextPredicate.CaptureMatchesPatternParameters: CustomDebugStringConvertible {
    package var debugDescription: String {
        "[TreeSitterTextPredicate.CaptureMatchesPatternParameters"
        + " captureIndex=\(captureIndex)"
        + " pattern=\(pattern)"
        + " isPositive=\(isPositive)"
        + "]"
    }
}
