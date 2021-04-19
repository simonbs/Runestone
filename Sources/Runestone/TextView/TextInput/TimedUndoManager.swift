//
//  TimedUndoManager.swift
//  
//
//  Created by Simon Støvring on 07/02/2021.
//

import Foundation

final class TimedUndoManager: UndoManager {
    private let endGroupingInterval: TimeInterval = 1
    private var endGroupingTimer: Timer?
    private var hasOpenGroup = false

    override init() {
        super.init()
        groupsByEvent = false
    }

    override func removeAllActions() {
        hasOpenGroup = false
        cancelTimer()
        super.removeAllActions()
    }

    override func beginUndoGrouping() {
        if !hasOpenGroup {
            hasOpenGroup = true
            super.beginUndoGrouping()
            if endGroupingTimer == nil {
                scheduleTimer()
            }
        }
    }

    override func endUndoGrouping() {
        if hasOpenGroup {
            hasOpenGroup = false
            cancelTimer()
            super.endUndoGrouping()
        }
    }

    override func undo() {
        endUndoGrouping()
        super.undo()
    }
}

private extension TimedUndoManager {
    private func scheduleTimer() {
        let timer = Timer(timeInterval: endGroupingInterval, target: self, selector: #selector(timerDidTrigger), userInfo: nil, repeats: false)
        endGroupingTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func cancelTimer() {
        endGroupingTimer?.invalidate()
        endGroupingTimer = nil
    }

    @objc private func timerDidTrigger() {
        cancelTimer()
        endUndoGrouping()
    }
}
