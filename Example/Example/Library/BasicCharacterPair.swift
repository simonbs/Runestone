//
//  BasicCharacterPair.swift
//  Example
//
//  Created by Simon on 24/01/2022.
//

import Runestone

final class BasicCharacterPair: CharacterPair {
    let leading: String
    let trailing: String

    init(leading: String, trailing: String) {
        self.leading = leading
        self.trailing = trailing
    }
}
