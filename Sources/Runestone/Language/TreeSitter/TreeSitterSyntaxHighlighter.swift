//
//  TreeSitterSyntaxHighlighter.swift
//  
//
//  Created by Simon Støvring on 16/01/2021.
//

import UIKit
import RunestoneTreeSitter
import RunestoneUtils

enum TreeSitterSyntaxHighlighterError: Error {
    case parserUnavailable
    case treeUnavailable
    case highlightsQueryUnavailable
}

final class TreeSitterSyntaxHighlighter {
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

    func captures(in range: ByteRange) -> Result<[Capture], TreeSitterSyntaxHighlighterError> {
        guard let parser = parser else {
            return .failure(.parserUnavailable)
        }
        guard let tree = parser.latestTree else {
            return .failure(.treeUnavailable)
        }
        guard let query = query else {
            return .failure(.highlightsQueryUnavailable)
        }
        let captureQuery = CaptureQuery(query: query, node: tree.rootNode)
        captureQuery.setQueryRange(range)
        captureQuery.execute()
        let captures = captureQuery.allCaptures()
        return .success(captures)
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

private extension TreeSitterSyntaxHighlighter {
    private func attributes(for capture: Capture, in range: ByteRange) -> SyntaxHighlightToken {
        let textColor = theme.textColorForCaptureSequence(capture.name)
        let font = theme.fontForCaptureSequence(capture.name)
        let shadow = theme.shadowForCaptureSequence(capture.name)
        return SyntaxHighlightToken(range: range, textColor: textColor, font: font, shadow: shadow)
    }
}
