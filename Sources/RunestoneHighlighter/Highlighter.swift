//
//  Highlighter.swift
//  
//
//  Created by Simon Støvring on 18/12/2020.
//

import Foundation
import TreeSitterBindings
import TreeSitterLanguages

public enum HighlighterError: Error {
    case treeUnavailable
    case queryError(QueryError)
}

@objc public protocol HighlighterDelegate: AnyObject {
    func highlighter(_ highlighter: Highlighter, linePositionAtLocation location: Int) -> HighlighterLinePosition
    func highlighter(_ highlighter: Highlighter, substringAtLocation location: Int) -> String?
}

@objc public final class Highlighter: NSObject {
    @objc public weak var delegate: HighlighterDelegate?

    private let parser: Parser
    private let highlightsSource: String
    private let language: Language

    @objc(initWithEncoding:)
    public init(encoding: HighlighterEncoding) {
        self.language = Language(tree_sitter_javascript())
        self.parser = Parser(encoding: encoding.sourceEncoding)
        self.parser.language = language
        let fileURL = Bundle.module.url(forResource: "highlights", withExtension: "scm", subdirectory: "queries/javascript")!
        self.highlightsSource = try! String(contentsOf: fileURL)
        super.init()
        parser.delegate = self
    }

    @discardableResult
    @objc public func markRangeEdited(_ range: NSRange) -> Bool {
        let startByte = range.location
        var oldEndByte = range.location
        var newEndByte = range.location
        if range.length < 0 {
            oldEndByte += range.length * -1
        } else {
            newEndByte += range.length
        }
        guard let startLinePosition = delegate?.highlighter(self, linePositionAtLocation: startByte) else {
            return false
        }
        guard let oldEndLinePosition = delegate?.highlighter(self, linePositionAtLocation: oldEndByte) else {
            return false
        }
        guard let newEndLinePosition = delegate?.highlighter(self, linePositionAtLocation: newEndByte) else {
            return false
        }
        let startPoint = SourcePoint(row: CUnsignedInt(startLinePosition.lineNumber), column: CUnsignedInt(startLinePosition.column))
        let oldEndPoint = SourcePoint(row: CUnsignedInt(oldEndLinePosition.lineNumber), column: CUnsignedInt(oldEndLinePosition.column))
        let newEndPoint = SourcePoint(row: CUnsignedInt(newEndLinePosition.lineNumber), column: CUnsignedInt(newEndLinePosition.column))
        let inputEdit = InputEdit(
            startByte: CUnsignedInt(startByte),
            oldEndByte: CUnsignedInt(oldEndByte),
            newEndByte: CUnsignedInt(newEndByte),
            startPoint: startPoint,
            oldEndPoint: oldEndPoint,
            newEndPoint: newEndPoint)
        return parser.apply(inputEdit)
    }

    @objc public func processEditing() throws -> HighlighterEditProcessingResult {
        parser.parse()
        let capturesResult = getCaptures()
        switch capturesResult {
        case .success(let captures):
            let tokens = captures.map(HighlightToken.init)
            return HighlighterEditProcessingResult(tokens: tokens)
        case .failure(let error):
            throw error
        }
    }
}

private extension Highlighter {
    private func getCaptures() -> Result<[Capture], HighlighterError> {
        guard let tree = parser.latestTree else {
            return .failure(.treeUnavailable)
        }
        return Query.create(fromSource: highlightsSource, in: language).mapError { error in
            return .queryError(error)
        }.map { query in
            let captureQuery = CaptureQuery(query: query, node: tree.rootNode)
            captureQuery.execute()
            return captureQuery.allCaptures()
        }
    }
}

extension Highlighter: ParserDelegate {
    public func parser(_ parser: Parser, substringAtByteIndex byteIndex: uint, point: SourcePoint) -> String? {
        return delegate?.highlighter(self, substringAtLocation: Int(byteIndex))
    }
}

private extension HighlightToken {
    convenience init(capture: Capture) {
        let location = Int(capture.startByte)
        let length = Int(capture.endByte - capture.startByte)
        let range = NSRange(location: location, length: length)
        self.init(range: range, name: capture.name)
    }
}
