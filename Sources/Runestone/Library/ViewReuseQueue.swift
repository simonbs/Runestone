//
//  ViewReuseQueue.swift
//  
//
//  Created by Simon Støvring on 27/01/2021.
//

import UIKit

final class ViewReuseQueue<Key: Hashable, View: UIView> {
    private(set) var visibleViews: [Key: View] = [:]
    
    private var queuedViews: Set<View> = []

    func enqueueViews(withKeys keys: Set<Key>) {
        for key in keys {
            if let view = visibleViews.removeValue(forKey: key) {
                view.removeFromSuperview()
                queuedViews.insert(view)
            }
        }
    }

    func dequeueView(forKey key: Key) -> View {
        if let view = visibleViews[key] {
            return view
        } else if !queuedViews.isEmpty {
            let view = queuedViews.removeFirst()
            visibleViews[key] = view
            return view
        } else {
            let view = View()
            visibleViews[key] = view
            return view
        }
    }
}
