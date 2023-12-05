import Foundation

package struct TreeSitterPredicate {
    package enum Step {
        case capture(UInt32)
        case string(String)
    }

    package let name: String
    package let steps: [Step]

    package init(name: String, steps: [Step]) {
        self.name = name
        self.steps = steps
    }
}

extension TreeSitterPredicate: CustomDebugStringConvertible {
    package var debugDescription: String {
        "[TreeSitterPredicate name=\(name) steps=\(steps)]"
    }
}

extension TreeSitterPredicate.Step: CustomDebugStringConvertible {
    package var debugDescription: String {
        switch self {
        case .capture(let id):
            return "[TreeSitterPredicate.Step capture=\(id)]"
        case .string(let string):
            return "[TreeSitterPredicate.Step string=\(string)]"
        }
    }
}
