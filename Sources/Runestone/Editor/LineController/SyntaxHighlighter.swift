//
//  SyntaxHighlighter.swift
//  
//
//  Created by Simon Støvring on 16/01/2021.
//

import UIKit

enum SyntaxHighlighterError: Error {
    case parserUnavailable
    case treeUnavailable
    case highlightsQueryUnavailable
}

final class SyntaxHighlighter {
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

    func captures(in range: ByteRange) -> Result<[Capture], SyntaxHighlighterError> {
        guard let parser = parser else {
            return .failure(.parserUnavailable)
        }
        guard let tree = parser.latestTree else {
            return .failure(.treeUnavailable)
        }
        return getQuery().map { query in
            let captureQuery = CaptureQuery(query: query, node: tree.rootNode)
            captureQuery.setQueryRange(range)
            captureQuery.execute()
            return captureQuery.allCaptures()
        }
    }

    func tokens(for captures: [Capture], localTo range: ByteRange) -> [SyntaxHighlightToken] {
        var tokens: [SyntaxHighlightToken] = []
        for capture in captures {
            // We highlight each line separately but a capture may extend beyond a line, e.g. an unterminated string,
            // so we need to cap the start and end location to ensure it's within the line.
            let cappedStartByte = max(capture.byteRange.location, range.location)
            let cappedEndByte = min(capture.byteRange.location + capture.byteRange.length, range.location + range.length)
            let length = cappedEndByte - cappedStartByte
            if length > ByteCount(0) {
                let cappedRange = ByteRange(location: cappedStartByte - range.location, length: length)
                let attrs = attributes(for: capture, in: cappedRange)
                if !attrs.isEmpty {
                    tokens.append(attrs)
                }
            }
        }
        return tokens
    }
}

private extension SyntaxHighlighter {
    private func attributes(for capture: Capture, in range: ByteRange) -> SyntaxHighlightToken {
        let textColor = theme.textColorForCaptureSequence(capture.name)
        let font = theme.fontForCapture(named: capture.name)
        return SyntaxHighlightToken(range: range, textColor: textColor, font: font)
    }

    private func getQuery() -> Result<Query, SyntaxHighlighterError> {
        if let query = query {
            return .success(query)
        } else {
            return .failure(.highlightsQueryUnavailable)
        }
    }
}
