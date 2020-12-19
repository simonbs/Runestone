//
//  HighlighterEncoding.swift
//  
//
//  Created by Simon Støvring on 18/12/2020.
//

import Foundation
import TreeSitterBindings

@objc public enum HighlighterEncoding: Int {
    case utf8
    case utf16
}

extension HighlighterEncoding {
    var sourceEncoding: SourceEncoding {
        switch self {
        case .utf8:
            return .utf8
        case .utf16:
            return .utf16
        }
    }
}
