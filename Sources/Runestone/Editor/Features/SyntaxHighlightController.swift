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
    case languageUnavailable
    case highlightsQueryUnavailable
    case queryError(QueryError)
}

final class SyntaxHighlightController {
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

    func reset() {
        query = nil
    }

    func attributes(in lineRange: NSRange) -> [EditorTextRendererAttributes] {
        guard lineRange.length > 0 else {
            return []
        }
        let capturesResult = captures(in: lineRange)
        switch capturesResult {
        case .success(let captures):
            let attributes = self.attributes(for: captures, in: lineRange)
            return attributes.sorted(by: EditorTextRendererAttributes.locationSort(_:_:))
        case .failure(let error):
            print(error)
            return []
        }
    }
}

private extension SyntaxHighlightController {
    private func attributes(for captures: [Capture], in lineRange: NSRange) -> [EditorTextRendererAttributes] {
        var allAttributes: [EditorTextRendererAttributes] = []
        for capture in captures {
            // We highlight each line separately but a capture may extend beyond a line, e.g. an unterminated string,
            // so we need to cap the start and end location to ensure it's within the line.
            let captureStartLocation = Int(capture.startByte)
            let captureEndLocation = Int(capture.endByte)
            let cappedStartLocation = max(captureStartLocation, lineRange.location)
            let cappedEndLocation = min(captureEndLocation, lineRange.location + lineRange.length)
            let length = cappedEndLocation - cappedStartLocation
            if length > 0 {
                let range = NSRange(location: cappedStartLocation - lineRange.location, length: length)
                let attrs = attributes(for: capture, in: range)
                if !attrs.isEmpty {
                    allAttributes.append(attrs)
                }
            }
        }
        return allAttributes
    }

    private func attributes(for capture: Capture, in range: NSRange) -> EditorTextRendererAttributes {
        let textColor = theme.textColorForCaptureSequence(capture.name)
        let font = theme.fontForCapture(named: capture.name)
        return EditorTextRendererAttributes(range: range, textColor: textColor, font: font)
    }

    private func captures(in range: NSRange) -> Result<[Capture], SyntaxHighlightControllerError> {
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

    private func getQuery() -> Result<Query, SyntaxHighlightControllerError> {
        if let query = query {
            return .success(query)
        } else {
            guard let parser = parser else {
                return .failure(.parserUnavailable)
            }
            guard let language = parser.language else {
                return .failure(.languageUnavailable)
            }
            language.highlightsQuery.prepare()
            guard let highlightsSource = language.highlightsQuery.string else {
                return .failure(.highlightsQueryUnavailable)
            }
            return Query.create(fromSource: highlightsSource, in: language).mapError { error in
                return .queryError(error)
            }.map { query in
                self.query = query
                return query
            }
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
