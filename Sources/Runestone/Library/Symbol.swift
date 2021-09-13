//
//  Symbol.swift
//  
//
//  Created by Simon Støvring on 11/12/2020.
//

import Foundation

enum Symbol {
    enum Character {
        static let lineFeed: Swift.Character = "\n"
        static let carriageReturn: Swift.Character = "\r"
        static let carriageReturnLineFeed: Swift.Character = "\r\n"
        static let tab: Swift.Character = "\t"
        static let space: Swift.Character = " "
    }

    static let lineFeed = String(Symbol.Character.lineFeed)
    static let carriageReturn = String(Symbol.Character.carriageReturn)
    static let carriageReturnLineFeed = String(Symbol.Character.carriageReturnLineFeed)
    static let tab = String(Symbol.Character.tab)
    static let space = String(Symbol.Character.space)
}
