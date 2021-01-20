//
//  SyntaxHighlightController.swift
//  
//
//  Created by Simon Støvring on 16/01/2021.
//

import UIKit

enum SyntaxHighlightControllerError: Error {
    case parserUnavailable
    case treeUnavailable
    case highlightsQueryUnavailable
}

protocol SyntaxHighlightControllerDelegate: AnyObject {
    func syntaxHighlightController(_ controller: SyntaxHighlightController, rangeFromStartByte startByte: uint, to endByte: uint) -> NSRange
}

final class SyntaxHighlightController {
    weak var delegate: SyntaxHighlightControllerDelegate?
    var parser: Parser?
    var theme: EditorTheme = DefaultEditorTheme()
    var canHighlight: Bool {
        if let parser = parser {
            return parser.language != nil && parser.latestTree != nil
        } else {
            return false
        }
    }

    private var query: Query?
    private var cache: [DocumentLineNodeID: [EditorTextRendererAttributes]] = [:]

    func reset() {
        query = nil
        cache = [:]
    }

    func prepare() {
        guard query == nil else {
            return
        }
        guard let language = parser?.language else {
            return
        }
        language.highlightsQuery.prepare()
        guard let highlightsSource = language.highlightsQuery.string else {
            return
        }
        if case let .success(query) = Query.create(fromSource: highlightsSource, in: language) {
            self.query = query
        }
    }

    func attributes(for captures: [Capture], in lineRange: NSRange) -> [EditorTextRendererAttributes] {
        var allAttributes: [EditorTextRendererAttributes] = []
        for capture in captures {
            // We highlight each line separately but a capture may extend beyond a line, e.g. an unterminated string,
            // so we need to cap the start and end location to ensure it's within the line.
            let range = self.delegate!.syntaxHighlightController(self, rangeFromStartByte: capture.startByte, to: capture.endByte)
            let cappedStartLocation = max(range.location, lineRange.location)
            let cappedEndLocation = min(range.location + range.length, lineRange.location + lineRange.length)
            let length = cappedEndLocation - cappedStartLocation
            if length > 0 {
                let cappedRange = NSRange(location: cappedStartLocation - lineRange.location, length: length)
                print("\(lineRange.location) [\(cappedRange.location) - \(cappedRange.length)] \(capture.name)")
//            let r = NSRange(location: range.location - lineRange.location, length: range.length)
//            print("\(lineRange.location) [\(r.location) - \(r.length)] \(capture.name)")
                let attrs = attributes(for: capture, in: cappedRange)
                if !attrs.isEmpty {
                    allAttributes.append(attrs)
                } else {
                    print("  Empty")
                }
            } else {
                print("\(lineRange.location) Discarded: [\(range.location) - \(range.length)] \(capture.name)")
            }
        }
        return allAttributes
    }

    func captures(in range: NSRange) -> Result<[Capture], SyntaxHighlightControllerError> {
        guard let parser = parser else {
            return .failure(.parserUnavailable)
        }
        guard let tree = parser.latestTree else {
            return .failure(.treeUnavailable)
        }
        return getQuery().map { query in
            let captureQuery = CaptureQuery(query: query, node: tree.rootNode)
            let startLocation = UInt32(range.location)
            let endLocation = UInt32(range.location + range.length)
            captureQuery.setQueryRange(from: startLocation, to: endLocation)
            captureQuery.execute()
            return captureQuery.allCaptures()
        }
    }

    func cache(_ attributes: [EditorTextRendererAttributes], for lineID: DocumentLineNodeID) {
        cache[lineID] = attributes
    }

    func cachedAttributes(for lineID: DocumentLineNodeID) -> [EditorTextRendererAttributes]? {
        return cache[lineID]
    }

    func clearCache() {
        cache = [:]
    }

    func removedCachedAttributes(for lineID: DocumentLineNodeID) {
        cache.removeValue(forKey: lineID)
    }
}

private extension SyntaxHighlightController {
    private func attributes(for capture: Capture, in range: NSRange) -> EditorTextRendererAttributes {
        let textColor = theme.textColorForCaptureSequence(capture.name)
        let font = theme.fontForCapture(named: capture.name)
        return EditorTextRendererAttributes(range: range, textColor: textColor, font: font)
    }

    private func getQuery() -> Result<Query, SyntaxHighlightControllerError> {
        if let query = query {
            return .success(query)
        } else {
            return .failure(.highlightsQueryUnavailable)
        }
    }
}

private extension EditorTextRendererAttributes {
    static func locationSort(_ lhs: EditorTextRendererAttributes, _ rhs: EditorTextRendererAttributes) -> Bool {
        if lhs.range.location != rhs.range.location {
            return lhs.range.location < rhs.range.location
        } else {
            return lhs.range.length < rhs.range.length
        }
    }
}
