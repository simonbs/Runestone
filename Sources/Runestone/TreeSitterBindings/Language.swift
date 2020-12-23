//
//  Language.swift
//  
//
//  Created by Simon Støvring on 05/12/2020.
//

import Foundation
import TreeSitter

final class Language {
    let pointer: UnsafePointer<TSLanguage>

    init(_ language: UnsafePointer<TSLanguage>) {
        self.pointer = language
    }
}
