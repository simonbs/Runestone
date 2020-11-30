//
//  File.swift
//  
//
//  Created by Simon Støvring on 30/11/2020.
//

import Foundation

extension Array {
    func mapAll<T, E: Error>(_ transform: (Element) -> Result<T, E>) -> Result<[T], E> {
        var mappedElements: [T] = []
        for element in self {
            let elementResult = transform(element)
            switch elementResult {
            case .success(let mappedElement):
                mappedElements.append(mappedElement)
            case .failure(let error):
                return .failure(error)
            }
        }
        return .success(mappedElements)
    }
}
