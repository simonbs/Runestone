//
//  SyntaxHighlightController.swift
//  
//
//  Created by Simon Støvring on 18/12/2020.
//

import UIKit
import TreeSitterLanguages

enum SyntaxHighlightControllerError: Error {
    case treeUnavailable
    case languageUnavailable
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

    private let parser: Parser
    private weak var lineManager: LineManager?
    private weak var textStorage: NSTextStorage?
    private let highlightsSource: String

    init(parser: Parser, lineManager: LineManager, textStorage: NSTextStorage, theme: EditorTheme) {
        self.parser = parser
        self.lineManager = lineManager
        self.textStorage = textStorage
        self.theme = theme
        let fileURL = Bundle.module.url(forResource: "highlights", withExtension: "scm", subdirectory: "queries/javascript")!
        self.highlightsSource = try! String(contentsOf: fileURL)
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

    func processEditing(_ range: NSRange) {
        let capturesResult = getCaptures(in: range)
        switch capturesResult {
        case .success(let captures):
            highlight(captures, in: range)
        case .failure(let error):
            print(error)
        }
    }
}

private extension SyntaxHighlightController {
    private func highlight(_ captures: [Capture], in range: NSRange) {
        textStorage?.removeAttribute(.font, range: range)
        textStorage?.removeAttribute(.foregroundColor, range: range)
        var defaulAttributes: [NSAttributedString.Key: Any] = [:]
        if let textColor = textColor {
            defaulAttributes[.foregroundColor] = textColor
        }
        if let font = font {
            defaulAttributes[.font] = font
        }
        if !defaulAttributes.isEmpty {
            textStorage?.addAttributes(defaulAttributes, range: range)
        }
        for capture in captures {
            let location = Int(capture.startByte)
            let length = Int(capture.endByte - capture.startByte)
            let captureRange = NSRange(location: location, length: length)
            var attrs: [NSAttributedString.Key: Any] = [:]
            if let textColor = theme.textColorForCapture(named: capture.name) {
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
                textStorage?.addAttributes(attrs, range: captureRange)
            }
        }
    }

    private func getCaptures(in range: NSRange) -> Result<[Capture], SyntaxHighlightControllerError> {
        guard let tree = parser.latestTree else {
            return .failure(.treeUnavailable)
        }
        guard let language = parser.language else {
            return .failure(.languageUnavailable)
        }
        return Query.create(fromSource: highlightsSource, in: language).mapError { error in
            return .queryError(error)
        }.map { query in
            let captureQuery = CaptureQuery(query: query, node: tree.rootNode)
            let startLocation = UInt32(range.location)
            let endLocation = UInt32(range.location + range.length)
            captureQuery.setQueryRange(from: startLocation, to: endLocation)
            captureQuery.execute()
            return captureQuery.allCaptures()
        }
    }
}

private extension SourcePoint {
    convenience init(_ linePosition: LinePosition) {
        self.init(row: UInt32(linePosition.lineNumber), column: UInt32(linePosition.column))
    }
}
