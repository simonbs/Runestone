//
//  File.swift
//  
//
//  Created by Simon Støvring on 08/12/2020.
//

import Foundation

enum NewLineSymbol {
    static let carriageReturn = "\r"
    static let lineFeed = "\n"
    static let nsCarriageReturn = NewLineSymbol.carriageReturn as NSString
    static let nsLineFeed = NewLineSymbol.lineFeed as NSString
}
