//
//  TreeSitterPredicatesValidator.swift
//  
//
//  Created by Simon Støvring on 23/02/2021.
//

import Foundation

final class TreeSitterTextPredicatesEvaluator {
    typealias TextCallback = (ByteRange) -> String?

    private let match: TreeSitterQueryMatch
    private let textCallback: TextCallback

    init(match: TreeSitterQueryMatch, textCallback: @escaping TextCallback) {
        self.match = match
        self.textCallback = textCallback
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
            }
        }
        return true
    }
}

private extension TreeSitterTextPredicatesEvaluator {
    func evaluate(using parameters: TreeSitterTextPredicate.CaptureEqualsStringParameters) -> Bool {
        guard let capture = match.capture(forIndex: parameters.captureIndex) else {
            return false
        }
        guard let contentText = textCallback(capture.byteRange) else {
            return false
        }
        let comparisonResult = contentText == parameters.string
        return comparisonResult == parameters.isPositive
    }

    func evaluate(using parameters: TreeSitterTextPredicate.CaptureEqualsCaptureParameters) -> Bool {
        guard let lhsCapture = match.capture(forIndex: parameters.lhsCaptureIndex) else {
            return false
        }
        guard let rhsCapture = match.capture(forIndex: parameters.lhsCaptureIndex) else {
            return false
        }
        guard let lhsContentText = textCallback(lhsCapture.byteRange) else {
            return false
        }
        guard let rhsContentText = textCallback(rhsCapture.byteRange) else {
            return false
        }
        let comparisonResult = lhsContentText == rhsContentText
        return comparisonResult == parameters.isPositive
    }
}
