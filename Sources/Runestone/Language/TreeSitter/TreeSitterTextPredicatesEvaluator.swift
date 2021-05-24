//
//  TreeSitterPredicatesValidator.swift
//  
//
//  Created by Simon Støvring on 23/02/2021.
//

import Foundation

final class TreeSitterTextPredicatesEvaluator {
    private let match: TreeSitterQueryMatch
    private let stringView: StringView

    init(match: TreeSitterQueryMatch, stringView: StringView) {
        self.match = match
        self.stringView = stringView
    }

    func evaluatePredicates(in capture: TreeSitterCapture) -> Bool {
        guard !capture.textPredicates.isEmpty else {
            return true
        }
        for textPredicate in capture.textPredicates {
            switch textPredicate {
            case .captureEqualsString(let parameters):
                if !evaluate(using: parameters) {
                    return false
                }
            case .captureEqualsCapture(let parameters):
                if !evaluate(using: parameters) {
                    return false
                }
            case .captureMatchesPattern(let parameters):
                if !evaluate(using: parameters) {
                    return false
                }
            }
        }
        return true
    }
}

private extension TreeSitterTextPredicatesEvaluator {
    func evaluate(using parameters: TreeSitterTextPredicate.CaptureEqualsStringParameters) -> Bool {
        return false
//        guard let capture = match.capture(forIndex: parameters.captureIndex) else {
//            return false
//        }
//        let contentText = stringView.substring(in: capture.byteRange)
//        let comparisonResult = contentText == parameters.string
//        return comparisonResult == parameters.isPositive
    }

    func evaluate(using parameters: TreeSitterTextPredicate.CaptureEqualsCaptureParameters) -> Bool {
        return false
//        guard let lhsCapture = match.capture(forIndex: parameters.lhsCaptureIndex) else {
//            return false
//        }
//        guard let rhsCapture = match.capture(forIndex: parameters.lhsCaptureIndex) else {
//            return false
//        }
//        let lhsContentText = stringView.substring(in: lhsCapture.byteRange)
//        let rhsContentText = stringView.substring(in: rhsCapture.byteRange)
//        let comparisonResult = lhsContentText == rhsContentText
//        return comparisonResult == parameters.isPositive
    }

    func evaluate(using parameters: TreeSitterTextPredicate.CaptureMatchesPatternParameters) -> Bool {
        return false
//        guard let capture = match.capture(forIndex: parameters.captureIndex) else {
//            return false
//        }
//        guard let contentText = stringView.substring(in: capture.byteRange) else {
//            return false
//        }
//        let matchingRange = contentText.range(of: parameters.pattern, options: .regularExpression)
//        let isMatch = matchingRange != nil
//        return isMatch == parameters.isPositive
    }
}
