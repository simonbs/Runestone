//
//  TextPreview.swift
//  
//
//  Created by Simon on 28/08/2021.
//

import Foundation

public struct TextPreview {
    public let string: String
    public let localRange: NSRange
    public let isStartTruncated: Bool
    public let isEndTruncated: Bool
}
