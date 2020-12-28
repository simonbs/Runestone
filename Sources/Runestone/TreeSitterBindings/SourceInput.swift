//
//  SourceInput.swift
//  
//
//  Created by Simon Støvring on 05/12/2020.
//

import TreeSitter

typealias SourceProviderCallback = (_ byteIndex: uint, _ position: SourcePoint) -> [Int8]
private typealias SourceInputRead = @convention(c) (UnsafeMutableRawPointer?, UInt32, TSPoint, UnsafeMutablePointer<UInt32>?) -> UnsafePointer<Int8>?

final class SourceInput {
    struct Payload {
        var callback: SourceProviderCallback
        var bytePointers: [UnsafePointer<Int8>] = []
    }

    let rawInput: TSInput
    
    private var payload: Payload

    init(encoding: SourceEncoding, callback: @escaping SourceProviderCallback) {
        self.payload = Payload(callback: callback)
        let read: SourceInputRead = { payload, byteIndex, position, bytesRead in
            var payload = payload!.assumingMemoryBound(to: Payload.self).pointee
            let point = SourcePoint(point: position)
            let bytes = payload.callback(byteIndex, point)
            assert(!(bytes.count > 1 && bytes.last == 0), "Parser callback bytes should not be null terminated")
            bytesRead!.initialize(to: UInt32(bytes.count))
            // Allocate pointer and copy bytes
            let resultBytesPointer = UnsafeMutablePointer<Int8>.allocate(capacity: bytes.count)
            for i in 0 ..< bytes.count {
                (resultBytesPointer + i).initialize(to: bytes[i])
            }
            payload.bytePointers.append(resultBytesPointer)
            return UnsafePointer(resultBytesPointer)
        }
        rawInput = withUnsafeMutableBytes(of: &payload) {
            TSInput(payload: $0.baseAddress, read: read, encoding: encoding.treeSitterEncoding)
        }
    }

    func deallocate() {
        for pointer in payload.bytePointers {
            pointer.deallocate()
        }
    }
}
