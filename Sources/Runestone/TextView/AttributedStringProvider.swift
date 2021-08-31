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

    private let lineController: LineController
    private var observers: [ObjectIdentifier: WeakObserver] = [:]

    init(lineController: LineController) {
        self.lineController = lineController
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
        let location = lineController.line.location + lineController.line.value
        lineController.willDisplay(toLocation: location, syntaxHighlightAsynchronously: true)
        attributedString = lineController.attributedString
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
}

extension AttributedStringProvider: LineControllerAttributedStringObserver {
    func lineControllerDidUpdateAttributedString(_ lineController: LineController) {
        attributedString = lineController.attributedString
        invokeEachObserver { $0.attributedStringProviderDidUpdateAttributedString(self) }
    }
}
