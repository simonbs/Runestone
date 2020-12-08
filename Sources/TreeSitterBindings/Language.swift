//
//  File.swift
//  
//
//  Created by Simon Støvring on 05/12/2020.
//

import Foundation
import TreeSitter

@objc public final class Language: NSObject {
    let pointer: UnsafePointer<TSLanguage>

    @objc(initWithLanguage:) public init(_ language: UnsafePointer<TSLanguage>) {
        self.pointer = language
        super.init()
    }
}
