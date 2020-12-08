//
//  File.swift
//  
//
//  Created by Simon Støvring on 08/12/2020.
//

import UIKit

//final class DemoTextStorage: NSTextStorage {
//    override var string: String {
//        return internalString.string
//    }
//
//    private let internalString = NSMutableAttributedString()
//    private let lineManager = LineManager()
//
//    override func replaceCharacters(in range: NSRange, with str: String) {
//        beginEditing()
//        internalString.replaceCharacters(in: range, with: str)
//        lineManager.remove(range)
//        lineManager.insert(str, in: range)
//        edited(.editedCharacters, range: range, changeInLength: str.count - range.length)
//        endEditing()
//    }
//
//    override func setAttributes(_ attrs: [NSAttributedString.Key : Any]?, range: NSRange) {
//        beginEditing()
//        internalString.setAttributes(attrs, range: range)
//        edited(.editedAttributes, range: range, changeInLength: 0)
//        endEditing()
//    }
//
//    override func attributes(at location: Int, effectiveRange range: NSRangePointer?) -> [NSAttributedString.Key: Any] {
//        return internalString.attributes(at: location, effectiveRange: range)
//    }
//
//    override func processEditing() {
//        super.processEditing()
//    }
//}
