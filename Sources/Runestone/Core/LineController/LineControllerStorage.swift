import Combine

final class LineControllerStorage {
    subscript(_ lineID: LineNodeID) -> LineController? {
        lineControllers[lineID]
    }

    fileprivate var numberOfLineControllers: Int {
        lineControllers.count
    }

    private let stringView: CurrentValueSubject<StringView, Never>
    private let lineControllerFactory: LineControllerFactory
    private var lineControllers: [LineNodeID: LineController] = [:]

    init(stringView: CurrentValueSubject<StringView, Never>, lineControllerFactory: LineControllerFactory) {
        self.stringView = stringView
        self.lineControllerFactory = lineControllerFactory
    }

    func getOrCreateLineController(for line: LineNode) -> LineController {
        if let cachedLineController = lineControllers[line.id] {
            return cachedLineController
        } else {
            let lineController = lineControllerFactory.makeLineController(for: line)
            lineControllers[line.id] = lineController
            return lineController
        }
    }

    func removeLineController(withID lineID: LineNodeID) {
        lineControllers.removeValue(forKey: lineID)
    }

    func removeAllLineControllers() {
        lineControllers.removeAll()
    }

    func removeAllLineControllers(exceptLinesWithID exceptionLineIDs: Set<LineNodeID>) {
        let allLineIDs = Set(lineControllers.keys)
        let lineIDsToRelease = allLineIDs.subtracting(exceptionLineIDs)
        for lineID in lineIDsToRelease {
            lineControllers.removeValue(forKey: lineID)
        }
    }
}

extension LineControllerStorage: Sequence {
    struct Iterator: IteratorProtocol {
        private let lineControllers: [LineController]
        private var index = 0

        init(lineControllers: [LineController]) {
            self.lineControllers = lineControllers
        }

        mutating func next() -> LineController? {
            if index < lineControllers.count {
                let lineController = lineControllers[index]
                index += 1
                return lineController
            } else {
                return nil
            }
        }
    }

    func makeIterator() -> Iterator {
        let lineControllers = Array(lineControllers.values)
        return Iterator(lineControllers: lineControllers)
    }
}
