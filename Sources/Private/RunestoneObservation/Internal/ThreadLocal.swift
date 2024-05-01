import Foundation

struct ThreadLocal {
    private struct Key: Hashable {}

    static var value: AccessList? {
        get {
            Thread.current.threadDictionary[Key()] as! AccessList?
        }
        set {
            Thread.current.threadDictionary[Key()] = newValue
        }
    }
}
