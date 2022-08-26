protocol LineControllerStorageDelegate: AnyObject {
    func lineControllerStorage(_ storage: LineControllerStorage, didCreate lineController: LineController)
}

final class LineControllerStorage {
    weak var delegate: LineControllerStorageDelegate?
    subscript(_ lineID: DocumentLineNodeID) -> LineController? {
        return lineControllers[lineID]
    }

    fileprivate var numberOfLineControllers: Int {
        return lineControllers.count
    }

    var stringView: StringView {
        didSet {
            if stringView !== oldValue {
                lineControllers.removeAll()
            }
        }
    }
    private var lineControllers: [DocumentLineNodeID: LineController] = [:]
    
    init(stringView: StringView) {
        self.stringView = stringView
    }
    
    func getOrCreateLineController(for line: DocumentLineNode) -> LineController {
        if let cachedLineController = lineControllers[line.id] {
            return cachedLineController
        } else {
            let lineController = LineController(line: line, stringView: stringView)
            lineControllers[line.id] = lineController
            delegate?.lineControllerStorage(self, didCreate: lineController)
            return lineController
        }
    }

    func removeLineController(withID lineID: DocumentLineNodeID) {
        lineControllers.removeValue(forKey: lineID)
    }

    func removeAllLineControllers(exceptLinesWithID exceptionLineIDs: Set<DocumentLineNodeID>) {
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
