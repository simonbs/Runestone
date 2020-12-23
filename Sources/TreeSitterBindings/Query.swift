//
//  Query.swift
//  
//
//  Created by Simon Støvring on 18/12/2020.
//

import TreeSitter

public enum QueryError: Error {
    case syntax(offset: UInt32)
    case nodeType(offset: UInt32)
    case field(offset: UInt32)
    case capture(offset: UInt32)
    case structure(offset: UInt32)
    case unknown
}

public final class Query {
    let pointer: OpaquePointer
    
    private let language: Language

    fileprivate init(language: Language, pointer: OpaquePointer) {
        self.language = language
        self.pointer = pointer
    }

    deinit {
        ts_query_delete(pointer)
    }

    public static func create(fromSource source: String, in language: Language) -> Result<Query, QueryError> {
        let errorOffset = UnsafeMutablePointer<UInt32>.allocate(capacity: 1)
        let errorType = UnsafeMutablePointer<TSQueryError>.allocate(capacity: 1)
        let pointer = source.withCString { cstr in
            ts_query_new(language.pointer, cstr, UInt32(source.count), errorOffset, errorType)
        }
        defer {
            errorOffset.deallocate()
            errorType.deallocate()
        }
        switch errorType.pointee.rawValue {
        case 1:
            return .failure(.syntax(offset: errorOffset.pointee))
        case 2:
            return .failure(.nodeType(offset: errorOffset.pointee))
        case 3:
            return .failure(.field(offset: errorOffset.pointee))
        case 4:
            return .failure(.capture(offset: errorOffset.pointee))
        case 5:
            return .failure(.structure(offset: errorOffset.pointee))
        default:
            if let pointer = pointer {
                return .success(Query(language: language, pointer: pointer))
            } else {
                return .failure(.unknown)
            }
        }
    }

    func captureName(forId id: UInt32) -> String {
        let lengthPointer = UnsafeMutablePointer<UInt32>.allocate(capacity: 1)
        let cString = ts_query_capture_name_for_id(pointer, id, lengthPointer)
        lengthPointer.deallocate()
        return String(cString: cString!)
    }
}
