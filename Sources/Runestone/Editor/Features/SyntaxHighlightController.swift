//
//  SyntaxHighlightController.swift
//  
//
//  Created by Simon Støvring on 18/12/2020.
//

import UIKit

enum SyntaxHighlightControllerError: Error {
    case treeUnavailable
    case languageUnavailable
    case highlightsQueryUnavailable
    case queryError(QueryError)
}

final class SyntaxHighlightController {
    struct Edit {
        let location: Int
        let bytesRemoved: Int
        let bytesAdded: Int
        let startLinePosition: LinePosition
        let oldEndLinePosition: LinePosition
        let newEndLinePosition: LinePosition
    }

    var theme: EditorTheme
    var textColor: UIColor?
    var font: UIFont?
    var canHighlight: Bool {
        return parser.language != nil && parser.latestTree != nil
    }

    private let parser: Parser
    private weak var textStorage: NSTextStorage?
    private var query: Query?

    init(parser: Parser, textStorage: NSTextStorage, theme: EditorTheme) {
        self.parser = parser
        self.textStorage = textStorage
        self.theme = theme
    }

    @discardableResult
    func apply(_ edit: Edit) -> Bool {
        let inputEdit = InputEdit(
            startByte: UInt32(edit.location),
            oldEndByte: UInt32(edit.location + edit.bytesRemoved),
            newEndByte: UInt32(edit.location + edit.bytesAdded),
            startPoint: SourcePoint(edit.startLinePosition),
            oldEndPoint: SourcePoint(edit.oldEndLinePosition),
            newEndPoint: SourcePoint(edit.newEndLinePosition))
        return parser.apply(inputEdit)
    }

    func reset() {
        query = nil
    }

    func highlight(_ ranges: [NSRange]) {
        let capturesResult = getCaptures(in: ranges)
        switch capturesResult {
        case .success(let captures):
            setDefaultAttributes(in: ranges)
            addAttributes(to: captures)
        case .failure(let error):
            setDefaultAttributes(in: ranges)
            print(error)
        }
    }

    func removeHighlighting() {
        if let length = textStorage?.length {
            let range = NSRange(location: 0, length: length)
            setDefaultAttributes(in: [range])
        }
    }
}

private extension SyntaxHighlightController {
    private func setDefaultAttributes(in ranges: [NSRange]) {
        var attrs: [NSAttributedString.Key: Any] = [:]
        if let textColor = textColor {
            attrs[.foregroundColor] = textColor
        }
        if let font = font {
            attrs[.font] = font
        }
        for range in ranges {
            textStorage?.setAttributes(attrs, range: range)
        }
    }

    private func addAttributes(to captures: [Capture]) {
        for capture in captures {
            let location = Int(capture.startByte)
            let length = Int(capture.endByte - capture.startByte)
            let captureRange = NSRange(location: location, length: length)
            var attrs: [NSAttributedString.Key: Any] = [:]
            if let textColor = theme.textColorForCaptureSequence(capture.name) {
                attrs[.foregroundColor] = textColor
            } else if let textColor = textColor {
                attrs[.foregroundColor] = textColor
            }
            if let font = theme.fontForCapture(named: capture.name) {
                attrs[.font] = font
            } else if let font = font {
                attrs[.font] = font
            }
            if !attrs.isEmpty {
                textStorage?.setAttributes(attrs, range: captureRange)
            }
        }
    }

    private func getCaptures(in ranges: [NSRange]) -> Result<[Capture], SyntaxHighlightControllerError> {
        guard let tree = parser.latestTree else {
            return .failure(.treeUnavailable)
        }
        return getQuery().map { query in
            var allCaptures: [Capture] = []
            for range in ranges {
                let captureQuery = CaptureQuery(query: query, node: tree.rootNode)
                let startLocation = UInt32(range.location)
                let endLocation = UInt32(range.location + range.length)
                captureQuery.setQueryRange(from: startLocation, to: endLocation)
                captureQuery.execute()
                let captures = captureQuery.allCaptures()
                allCaptures.append(contentsOf: captures)
            }
            return allCaptures
        }
    }

    private func getQuery() -> Result<Query, SyntaxHighlightControllerError> {
        if let query = query {
            return .success(query)
        } else if let language = parser.language {
            language.highlightsQuery.prepare()
            if let highlightsSource = language.highlightsQuery.string {
                return Query.create(fromSource: highlightsSource, in: language).mapError { error in
                    return .queryError(error)
                }.map { query in
                    self.query = query
                    return query
                }
            } else {
                return .failure(.highlightsQueryUnavailable)
            }
        } else {
            return .failure(.languageUnavailable)
        }
    }
}

private extension SourcePoint {
    convenience init(_ linePosition: LinePosition) {
        self.init(row: UInt32(linePosition.lineNumber), column: UInt32(linePosition.column))
    }
}
