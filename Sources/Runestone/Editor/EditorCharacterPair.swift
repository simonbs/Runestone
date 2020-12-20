//
//  File.swift
//  
//
//  Created by Simon Støvring on 20/12/2020.
//

import Foundation

public struct EditorCharacterPair {
    public let leading: String
    public let trailing: String

    public init(leading: String, trailing: String) {
        self.leading = leading
        self.trailing = trailing
    }
}
