//
//  TreeSitterHighlightsQuery.swift
//  
//
//  Created by Simon Støvring on 11/02/2021.
//

import Foundation

public final class TreeSitterHighlightsQuery {
    public let fileURL: URL?
    public private(set) var string: String?

    private var isPrepared = false

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public init(string: String) {
        self.fileURL = nil
        self.string = string
    }

    func prepare() {
        if !isPrepared {
            isPrepared = true
            if string == nil, let fileURL = fileURL {
                string = try? String(contentsOf: fileURL)
            }
        }
    }
}
