//
//  File.swift
//  
//
//  Created by Simon Støvring on 01/12/2020.
//

import Foundation

protocol CodableWrapper: Codable {
    associatedtype WrappedValue
    var wrappedValue: WrappedValue { get }
    init(_ wrappedValue: WrappedValue)
}

extension KeyedDecodingContainer {
    func decodeWrappedValue<T: CodableWrapper>(_ type: T.Type, forKey key: K) throws -> T.WrappedValue {
        return try decode(T.self, forKey: key).wrappedValue
    }

    func decodeWrappedValueIfPresent<T: CodableWrapper>(_ type: T.Type, forKey key: K) throws -> T.WrappedValue? {
        return try decodeIfPresent(T.self, forKey: key)?.wrappedValue
    }

    func decodeWrappedValues<T: CodableWrapper>(_ type: [T].Type, forKey key: K) throws -> [T.WrappedValue] {
        return try decode([T].self, forKey: key).map(\.wrappedValue)
    }

    func decodeWrappedValuesIfPresent<T: CodableWrapper>(_ type: [T].Type, forKey key: K) throws -> [T.WrappedValue]? {
        return try decodeIfPresent([T].self, forKey: key)?.map(\.wrappedValue)
    }

    func decodeWrappedValues<U: Hashable & Decodable, T: CodableWrapper>(_ type: [U: T].Type, forKey key: K) throws -> [U: T.WrappedValue] {
        let unwrappedPairs = try decode([U: T].self, forKey: key).map { ($0, $1.wrappedValue) }
        return Dictionary(uniqueKeysWithValues: unwrappedPairs)
    }

    func decodeWrappedValues<U: Hashable & Decodable, T: CodableWrapper>(_ type: [U: T].Type, forKey key: K) throws -> [U: T.WrappedValue]? {
        if let pairs = try decodeIfPresent([U: T].self, forKey: key) {
            let unwrappedPairs = pairs.map { ($0, $1.wrappedValue) }
            return Dictionary(uniqueKeysWithValues: unwrappedPairs)
        } else {
            return nil
        }
    }
}

extension KeyedEncodingContainer {
    mutating func encodeWrappedValue<T: CodableWrapper>(_ value: T.WrappedValue?, to type: T.Type, forKey key: K) throws {
        if let value = value {
            try encode(T.init(value), forKey: key)
        } else {
            try encodeNil(forKey: key)
        }
    }

    mutating func encodeWrappedValues<T: CodableWrapper>(_ values: [T.WrappedValue]?, to type: [T].Type, forKey key: K) throws {
        if let values = values {
            try encode(values.map(T.init), forKey: key)
        } else {
            try encodeNil(forKey: key)
        }
    }

    mutating func encodeWrappedValues<U: Encodable & Hashable, T: CodableWrapper>(_ values: [U: T.WrappedValue]?, to type: [U: T].Type, forKey key: K) throws {
        if let values = values {
            let wrappedValues = Dictionary(uniqueKeysWithValues: values.map { ($0, T.init($1)) })
            try encode(wrappedValues, forKey: key)
        } else {
            try encodeNil(forKey: key)
        }
    }
}
