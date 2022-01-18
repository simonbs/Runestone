//
//  TextViewDelegate.swift
//  
//
//  Created by Simon on 04/11/2021.
//

import Foundation

/// The methods for receiving editing-related messages for the text view.
public protocol TextViewDelegate: AnyObject {
    func textViewShouldBeginEditing(_ textView: TextView) -> Bool
    func textViewShouldEndEditing(_ textView: TextView) -> Bool
    func textViewDidBeginEditing(_ textView: TextView)
    func textViewDidEndEditing(_ textView: TextView)
    func textViewDidChange(_ textView: TextView)
    func textViewDidChangeSelection(_ textView: TextView)
    func textView(_ textView: TextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool
    func textView(_ textView: TextView, shouldInsert characterPair: CharacterPair, in range: NSRange) -> Bool
    func textView(_ textView: TextView, shouldSkipTrailingComponentOf characterPair: CharacterPair, in range: NSRange) -> Bool
    func textViewDidUpdateGutterWidth(_ textView: TextView)
    func textViewDidBeginFloatingCursor(_ view: TextView)
    func textViewDidEndFloatingCursor(_ view: TextView)
    func textViewDidBeginDraggingCursor(_ view: TextView)
    func textViewDidEndDraggingCursor(_ view: TextView)
    func textViewDidLoopToLastHighlightedRange(_ view: TextView)
    func textViewDidLoopToFirstHighlightedRange(_ view: TextView)
    func textView(_ view: TextView, canReplaceTextIn highlightedRange: HighlightedRange) -> Bool
    func textView(_ view: TextView, replaceTextIn highlightedRange: HighlightedRange)
}

public extension TextViewDelegate {
    func textViewShouldBeginEditing(_ textView: TextView) -> Bool {
        return true
    }

    func textViewShouldEndEditing(_ textView: TextView) -> Bool {
        return true
    }

    func textViewDidBeginEditing(_ textView: TextView) {}

    func textViewDidEndEditing(_ textView: TextView) {}

    func textViewDidChange(_ textView: TextView) {}

    func textViewDidChangeSelection(_ textView: TextView) {}

    func textView(_ textView: TextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        return true
    }

    func textView(_ textView: TextView, shouldInsert characterPair: CharacterPair, in range: NSRange) -> Bool {
        return true
    }

    func textView(_ textView: TextView, shouldSkipTrailingComponentOf characterPair: CharacterPair, in range: NSRange) -> Bool {
        return true
    }

    func textViewDidUpdateGutterWidth(_ textView: TextView) {}

    func textViewDidBeginFloatingCursor(_ view: TextView) {}

    func textViewDidEndFloatingCursor(_ view: TextView) {}

    func textViewDidBeginDraggingCursor(_ view: TextView) {}

    func textViewDidEndDraggingCursor(_ view: TextView) {}

    func textViewDidLoopToLastHighlightedRange(_ view: TextView) {}

    func textViewDidLoopToFirstHighlightedRange(_ view: TextView) {}

    func textView(_ view: TextView, canReplaceTextIn highlightedRange: HighlightedRange) -> Bool {
        return false
    }

    func textView(_ view: TextView, replaceTextIn highlightedRange: HighlightedRange) {}
}
