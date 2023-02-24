import Foundation

public enum TreeSitterTextPredicate {
    public struct CaptureEqualsStringParameters {
        public let captureIndex: UInt32
        public let string: String
        public let isPositive: Bool

        init(captureIndex: UInt32, string: String, isPositive: Bool) {
            self.captureIndex = captureIndex
            self.string = string
            self.isPositive = isPositive
        }
    }

    public struct CaptureEqualsCaptureParameters {
        public let lhsCaptureIndex: UInt32
        public let rhsCaptureIndex: UInt32
        public let isPositive: Bool

        init(lhsCaptureIndex: UInt32, rhsCaptureIndex: UInt32, isPositive: Bool) {
            self.lhsCaptureIndex = lhsCaptureIndex
            self.rhsCaptureIndex = rhsCaptureIndex
            self.isPositive = isPositive
        }
    }

    public struct CaptureMatchesPatternParameters {
        public let captureIndex: UInt32
        public let pattern: String
        public let isPositive: Bool

        init(captureIndex: UInt32, pattern: String, isPositive: Bool) {
            self.captureIndex = captureIndex
            self.pattern = pattern
            self.isPositive = isPositive
        }
    }

    public struct UnsupportedParameters {
        public let name: String

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
    public var debugDescription: String {
        "[TreeSitterTextPredicate.CaptureEqualsStringParameters captureIndex=\(captureIndex) string=\(string) isPositive=\(isPositive)]"
    }
}

extension TreeSitterTextPredicate.CaptureEqualsCaptureParameters: CustomDebugStringConvertible {
    public var debugDescription: String {
        "[TreeSitterTextPredicate.CaptureEqualsCaptureParameters lhsCaptureIndex=\(lhsCaptureIndex)"
        + " rhsCaptureIndex=\(rhsCaptureIndex)"
        + " isPositive=\(isPositive)]"
    }
}

extension TreeSitterTextPredicate.CaptureMatchesPatternParameters: CustomDebugStringConvertible {
    public var debugDescription: String {
        "[TreeSitterTextPredicate.CaptureMatchesPatternParameters captureIndex=\(captureIndex) pattern=\(pattern) isPositive=\(isPositive)]"
    }
}
