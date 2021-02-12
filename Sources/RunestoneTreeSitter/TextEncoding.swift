//
//  TextEncoding.swift
//  
//
//  Created by Simon Støvring on 17/12/2020.
//

import TreeSitter

public enum TextEncoding {
    case utf8
    case utf16
}

extension TextEncoding {
    var treeSitterEncoding: TSInputEncoding {
        switch self {
        case .utf8:
            return TSInputEncodingUTF8
        case .utf16:
            return TSInputEncodingUTF16
        }
    }
}
