import Foundation

struct ThreadLocal {
    private struct Key: Hashable {}

    static var value: UnsafeMutableRawPointer? {
        get {
            Thread.current.threadDictionary[Key()] as! UnsafeMutableRawPointer?
        }
        set {
            Thread.current.threadDictionary[Key()] = newValue
        }
    }
}
