//
//  CaptureSequence.swift
//  Example
//
//  Created by Simon on 22/01/2022.
//

import Foundation

enum Scope: String {
    case comment
    case function
    case keyword
    case number
    case `operator`
    case property
    case punctuation
    case string
    case variableBuiltin = "variable.builtin"

    init?(captureSequence: String) {
        var comps = captureSequence.split(separator: ".")
        while !comps.isEmpty {
            let scopeName = comps.joined(separator: ".")
            if let scope = Scope(rawValue: scopeName) {
                self = scope
                return
            }
            comps.removeLast()
        }
        return nil
    }
}
