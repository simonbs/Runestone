//
//  Language.swift
//  
//
//  Created by Simon Støvring on 05/12/2020.
//

import Foundation
import TreeSitter

public final class Language {
    let pointer: UnsafePointer<TSLanguage>

    public init(_ language: UnsafePointer<TSLanguage>) {
        self.pointer = language
    }
}
