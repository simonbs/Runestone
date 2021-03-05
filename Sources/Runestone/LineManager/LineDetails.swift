//
//  LineDetails.swift
//  
//
//  Created by Simon Støvring on 25/02/2021.
//

import Foundation

public final class LineDetails {
    public let startLocation: Int
    public let totalLength: Int
    public let position: LinePosition

    init(startLocation: Int, totalLength: Int, position: LinePosition) {
        self.startLocation = startLocation
        self.totalLength = totalLength
        self.position = position
    }
}

extension LineDetails: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "[LinePosition startLocation=\(startLocation) totalLength=\(totalLength) position=\(position)]"
    }
}
