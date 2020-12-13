//
//  File.swift
//  
//
//  Created by Simon Støvring on 12/12/2020.
//

import UIKit

protocol EditorGutterControllerDelegate: AnyObject {
    func numberOfLines(in controller: EditorGutterController)
}

final class EditorGutterController {
    var lineNumbersFont: UIFont?

}
