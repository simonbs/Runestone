//
//  File.swift
//  
//
//  Created by Simon Støvring on 05/12/2020.
//

import Foundation

final class CaptureCollection: Codable {
    private let representation: [Int: Capture]

    init(from decoder: Decoder) throws {
        let valueContainer = try decoder.singleValueContainer()
        representation = try valueContainer.decode([Int: Capture].self)
    }

    private init(_ representation: [Int: Capture]) {
        self.representation = representation
    }

    func encode(to encoder: Encoder) throws {
        var valueContainer = encoder.singleValueContainer()
        try valueContainer.encode(representation)
    }

    func capture(at index: Int) -> Capture? {
        return representation[index]
    }

    func concat(_ otherCollection: CaptureCollection) -> CaptureCollection {
        var resultingRepresentation = representation
        resultingRepresentation.merge(otherCollection.representation) { $1 }
        return CaptureCollection(resultingRepresentation)
    }
}
