//
//  IndentController.swift
//  
//
//  Created by Simon Støvring on 01/03/2021.
//

import Foundation

protocol IndentController {
    func suggestedIndent(for line: DocumentLineNode)
}
