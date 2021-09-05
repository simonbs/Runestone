//
//  AttributedStringProvider.swift
//  
//
//  Created by Simon on 31/08/2021.
//

import Foundation

public protocol AttributedStringObserver: AnyObject {
    func attributedStringProviderDidUpdateAttributedString(_ provider: AttributedStringProvider)
}

public final class AttributedStringProvider {
    private final class WeakObserver {
        private(set) weak var observer: AttributedStringObserver?

        init(_ observer: AttributedStringObserver) {
            self.observer = observer
        }
    }

    public private(set) var attributedString: NSAttributedString?
    public private(set) var localLocation: Int?

    private let lineController: LineController
    private let locationInLine: Int
    private var observers: [ObjectIdentifier: WeakObserver] = [:]

    init(lineController: LineController, locationInLine: Int) {
        self.lineController = lineController
        self.locationInLine = locationInLine
        lineController.addObserver(self)
    }

    deinit {
        observers = [:]
    }

    public func addObserver(_ observer: AttributedStringObserver) {
        let identifier = ObjectIdentifier(observer)
        observers[identifier] = WeakObserver(observer)
        cleanUpObservers()
    }

    public func removeObserver(_ observer: AttributedStringObserver) {
        let identifier = ObjectIdentifier(observer)
        observers.removeValue(forKey: identifier)
        cleanUpObservers()
    }

    public func prepare() {
        updateAttributedString()
    }

    public func cancelSyntaxHighlighting() {
        lineController.cancelSyntaxHighlighting()
    }
}

private extension AttributedStringProvider {
    private func invokeEachObserver(_ handler: (AttributedStringObserver) -> ()) {
        for (_, value) in observers {
            if let observer = value.observer {
                handler(observer)
            }
        }
    }

    private func cleanUpObservers() {
        observers = observers.filter { $0.value.observer != nil }
    }

    private func updateAttributedString() {
        lineController.prepareToDisplayString(toLocation: locationInLine, syntaxHighlightAsynchronously: true)
        let range = rangeOfLineFragmentNodes(surroundingCharacterAt: locationInLine)
        localLocation = locationInLine - range.location
        attributedString = lineController.attributedString?.attributedSubstring(from: range)
    }

    private func rangeOfLineFragmentNodes(surroundingCharacterAt location: Int) -> NSRange {
        let startLocation: Int
        let endLocation: Int
        let lineFragmentNode = lineController.lineFragmentNode(containingCharacterAt: location)
        let index = lineFragmentNode.index
        if index > 0 {
            let previousLineFragmentNode = lineController.lineFragmentNode(atIndex: index - 1)
            startLocation = previousLineFragmentNode.location
        } else {
            startLocation = lineFragmentNode.location
        }
        if index < lineController.numberOfLineFragments - 1 {
            let nextLineFragmentNode = lineController.lineFragmentNode(atIndex: index + 1)
            endLocation = nextLineFragmentNode.location + nextLineFragmentNode.value
        } else if index == 0 {
            // Small optimization to avoid re-computing lineFragmentNode.location when there is no previous line.
            endLocation = startLocation + lineFragmentNode.value
        } else {
            endLocation = lineFragmentNode.location + lineFragmentNode.value
        }
        let length = endLocation - startLocation
        return NSRange(location: startLocation, length: length)
    }
}

extension AttributedStringProvider: LineControllerAttributedStringObserver {
    func lineControllerDidUpdateAttributedString(_ lineController: LineController) {
        updateAttributedString()
        invokeEachObserver { $0.attributedStringProviderDidUpdateAttributedString(self) }
    }
}
