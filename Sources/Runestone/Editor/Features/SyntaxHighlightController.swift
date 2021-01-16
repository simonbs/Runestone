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

    func attributes(in range: NSRange, lineStartLocation: Int) -> [EditorTextRendererAttributes] {
        guard range.length > 0 else {
            return []
        }
        let capturesResult = captures(in: range)
        switch capturesResult {
        case .success(let captures):
            return attributes(for: captures, lineStartLocation: lineStartLocation).sorted(by: EditorTextRendererAttributes.locationSort(_:_:))
        case .failure(let error):
            print(error)
            return []
        }
    }

//    func removeHighlighting() {
//        if let length = textStorage?.length {
//            let range = NSRange(location: 0, length: length)
//            setDefaultAttributes(in: [range])
//        }
//    }
}

private extension SyntaxHighlightController {
    private func attributes(for captures: [Capture], lineStartLocation: Int) -> [EditorTextRendererAttributes] {
        var allAttributes: [EditorTextRendererAttributes] = []
        for capture in captures {
            let location = Int(capture.startByte)
            let length = Int(capture.endByte - capture.startByte)
            let range = NSRange(location: location - lineStartLocation, length: length)
            let attrs = attributes(for: capture, in: range)
            if !attrs.isEmpty {
                allAttributes.append(attrs)
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
