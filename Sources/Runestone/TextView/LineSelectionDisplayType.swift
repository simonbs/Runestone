//
//  LineSelectionDisplayType.swift
//  
//
//  Created by Simon on 03/06/2021.
//

import Foundation

public enum LineSelectionDisplayType {
    case disabled
    case line
    case lineFragment
}

extension LineSelectionDisplayType {
    var shouldShowLineSelection: Bool {
        switch self {
        case .disabled:
            return false
        case .line, .lineFragment:
            return true
        }
    }
}
