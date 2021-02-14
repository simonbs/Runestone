//
//  LanguageMode.swift
//  
//
//  Created by Simon Støvring on 11/02/2021.
//

import Foundation

protocol LanguageModeDelegate: AnyObject {
    func languageMode(_ languageMode: LanguageMode, bytesAt byteIndex: ByteCount) -> [Int8]?
    func languageMode(_ languageMode: LanguageMode, byteOffsetAt location: Int) -> ByteCount
}

struct LanguageModeTextChange {
    let byteRange: ByteRange
    let newString: String
    let oldEndLinePosition: LinePosition
    let startLinePosition: LinePosition
    let newEndLinePosition: LinePosition
}

struct LanguageModeTextChangeResult {
    let changedLineIndices: Set<Int>
}

protocol LanguageMode: AnyObject {
    var delegate: LanguageModeDelegate? { get set }
    func parse(_ text: String)
    func parse(_ text: String, completion: @escaping ((Bool) -> Void))
    func textDidChange(_ change: LanguageModeTextChange) -> LanguageModeTextChangeResult
    func tokenType(at location: Int) -> String?
    func createLineSyntaxHighlighter() -> LineSyntaxHighlighter
}
