import Foundation

extension String {
    var byteCount: ByteCount {
        ByteCount(utf16.count * 2)
    }

    static var preferredUTF16Encoding: String.Encoding {
        // Implementation from https://github.com/ChimeHQ/SwiftTreeSitter/blob/main/Sources/SwiftTreeSitter/String%2BData.swift
        let dataA = "abc".data(using: .utf16LittleEndian)
        let dataB = "abc".data(using: .utf16)?.suffix(from: 2)
        return dataA == dataB ? .utf16LittleEndian : .utf16BigEndian
    }
}

extension String.Element {
    var isLineBreak: Bool {
        self == Symbol.Character.lineFeed
        || self == Symbol.Character.carriageReturn
        || self == Symbol.Character.carriageReturnLineFeed
    }
}
