//
//  Dictionary+Helpers.swift
//  
//
//  Created by Simon on 19/03/2021.
//

import Foundation

extension Dictionary {
    // Variant of Dictionary(grouping:by:) that skips null keys.
    init<S>(compactGrouping values: S, by keyForValue: (S.Element) throws -> Key?) rethrows where Value == [S.Element], S: Sequence {
        self.init()
        for value in values {
            if let groupName = try keyForValue(value) {
                var group = self[groupName] ?? []
                group.append(value)
                self[groupName] = group
            }
        }
    }
}
