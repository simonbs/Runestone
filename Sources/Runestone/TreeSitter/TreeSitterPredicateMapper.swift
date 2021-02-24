//
//  TreeSitterPredicateMapper.swift
//  
//
//  Created by Simon Støvring on 24/02/2021.
//

import Foundation

enum TreeSitterTextPredicate {
    final class CaptureEqualsStringParameters {
        let captureIndex: UInt32
        let string: String
        let isPositive: Bool

        init(captureIndex: UInt32, string: String, isPositive: Bool) {
            self.captureIndex = captureIndex
            self.string = string
            self.isPositive = isPositive
        }
    }

    struct CaptureEqualsCaptureParameters {
        let lhsCaptureIndex: UInt32
        let rhsCaptureIndex: UInt32
        let isPositive: Bool

        init(lhsCaptureIndex: UInt32, rhsCaptureIndex: UInt32, isPositive: Bool) {
            self.lhsCaptureIndex = lhsCaptureIndex
            self.rhsCaptureIndex = rhsCaptureIndex
            self.isPositive = isPositive
        }
    }

    case captureEqualsString(CaptureEqualsStringParameters)
    case captureEqualsCapture(CaptureEqualsCaptureParameters)
}

final class TreeSitterPredicateMapper {
    struct MapResult  {
        let properties: [String: String]
        let textPredicates: [TreeSitterTextPredicate]
    }

    static func map(_ predicates: [TreeSitterPredicate]) -> MapResult {
        var properties: [String: String] = [:]
        var textPredicates: [TreeSitterTextPredicate] = []
        for predicate in predicates {
            switch predicate.name {
            case "set!":
                let setProperties = self.properties(fromSetSteps: predicate.steps)
                properties[setProperties.name] = setProperties.value
            case "eq?":
                let textPredicate = self.textPredicate(fromEqSteps: predicate.steps, isPositive: true)
                textPredicates.append(textPredicate)
            case "not-eq?":
                let textPredicate = self.textPredicate(fromEqSteps: predicate.steps, isPositive: true)
                textPredicates.append(textPredicate)
            default:
                break
            }
        }
        return MapResult(properties: properties, textPredicates: textPredicates)
    }
}

private extension TreeSitterPredicateMapper {
    private static func properties(fromSetSteps steps: [TreeSitterPredicate.Step]) -> (name: String, value: String) {
        guard steps.count == 2 else {
            fatalError("Set predicate must contain exactly two steps.")
        }
        switch (steps[0], steps[1]) {
        case (.string(let name), .string(let value)):
            return (name, value)
        default:
            fatalError("Set predicate must contain exactly two string steps.")
        }
    }

    private static func textPredicate(fromEqSteps steps: [TreeSitterPredicate.Step], isPositive: Bool) -> TreeSitterTextPredicate {
        guard steps.count == 2 else {
            fatalError("eq? predicate must contain exactly stwo teps.")
        }
        switch (steps[0], steps[1]) {
        case (.capture(let captureIndex), .string(let value)):
            return .captureEqualsString(.init(captureIndex: captureIndex, string: value, isPositive: isPositive))
        case (.capture(let lhsCaptureIndex), .capture(let rhsCaptureIndex)):
            return .captureEqualsCapture(.init(lhsCaptureIndex: lhsCaptureIndex, rhsCaptureIndex: rhsCaptureIndex, isPositive: isPositive))
        default:
            fatalError("eq? predicate contains invalid combination of steps.")
        }
    }
}

extension TreeSitterTextPredicate.CaptureEqualsStringParameters: CustomDebugStringConvertible {
    var debugDescription: String {
        return "[TreeSitterTextPredicate.CaptureEqualsStringParameters captureIndex=\(captureIndex) string=\(string) isPositive=\(isPositive)]"
    }
}

extension TreeSitterTextPredicate.CaptureEqualsCaptureParameters: CustomDebugStringConvertible {
    var debugDescription: String {
        return "[TreeSitterTextPredicate.CaptureEqualsCaptureParameters lhsCaptureIndex=\(lhsCaptureIndex) rhsCaptureIndex=\(rhsCaptureIndex) isPositive=\(isPositive)]"
    }
}
