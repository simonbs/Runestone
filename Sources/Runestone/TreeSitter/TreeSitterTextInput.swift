//
//  TreeSitterTextInput.swift
//  
//
//  Created by Simon Støvring on 05/12/2020.
//

import TreeSitter

struct TreeSitterTextProviderResult {
    let bytes: UnsafePointer<Int8>
    let length: UInt32
}

typealias TreeSitterTextProviderCallback = (_ byteIndex: ByteCount, _ position: TreeSitterTextPoint) -> TreeSitterTextProviderResult?
private typealias TextInputRead = @convention(c) (UnsafeMutableRawPointer?, UInt32, TSPoint, UnsafeMutablePointer<UInt32>?) -> UnsafePointer<Int8>?

final class TreeSitterTextInput {
    struct Payload {
        var callback: TreeSitterTextProviderCallback
        var bytePointers: [UnsafePointer<Int8>] = []
    }

    let rawInput: TSInput
    
    private var payload: Payload

    init(encoding: TSInputEncoding, callback: @escaping TreeSitterTextProviderCallback) {
        self.payload = Payload(callback: callback)
        let read: TextInputRead = { payload, byteIndex, position, bytesRead in
            var payload = payload!.assumingMemoryBound(to: Payload.self).pointee
            let point = TreeSitterTextPoint(position)
            if let result = payload.callback(ByteCount(byteIndex), point) {
                bytesRead?.initialize(to: result.length)
                payload.bytePointers.append(result.bytes)
                return result.bytes
            } else {
                bytesRead?.initialize(to: 0)
                return nil
            }
        }
        rawInput = withUnsafeMutableBytes(of: &payload) { pointer in
            return TSInput(payload: pointer.baseAddress, read: read, encoding: encoding)
        }
    }

    func deallocate() {
        for pointer in payload.bytePointers {
            pointer.deallocate()
        }
    }
}
