//
//  ParsedReplacementString.swift
//  RegexReplace
//
//  Created by Simon on 14/11/2021.
//

import Foundation

struct ParsedReplacementString: Equatable {
    enum Component: Equatable {
        case text(String)
        case placeholder(Int)
    }

    let components: [Component]
    var containsPlaceholder: Bool {
        return components.contains(where: { component in
            switch component {
            case .text:
                return false
            case .placeholder:
                return true
            }
        })
    }

    func string(byMatching textCheckingResult: NSTextCheckingResult, in string: NSString) -> String {
        var result = ""
        for component in components {
            switch component {
            case .text(let text):
                result += text
            case .placeholder(let index):
                if index < textCheckingResult.numberOfRanges {
                    let range = textCheckingResult.range(at: index)
                    result += string.substring(with: range)
                } else {
                    // Placeholder is out of bounds so we just insert the raw placeholder.
                    result += "$\(index)"
                }
            }
        }
        return result
    }
}
