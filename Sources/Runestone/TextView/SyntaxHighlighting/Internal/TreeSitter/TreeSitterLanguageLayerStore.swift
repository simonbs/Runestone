import Foundation

final class TreeSitterLanguageLayerStore {
    var allIDs: [UnsafeRawPointer] {
        defer {
            semaphore.signal()
        }
        semaphore.wait()
        return Array(store.keys)
    }

    var allLayers: [TreeSitterLanguageLayer] {
        defer {
            semaphore.signal()
        }
        semaphore.wait()
        return Array(store.values)
    }

    var isEmpty: Bool {
        defer {
            semaphore.signal()
        }
        semaphore.wait()
        return store.isEmpty
    }

    private var store: [UnsafeRawPointer: TreeSitterLanguageLayer] = [:]
    private let semaphore = DispatchSemaphore(value: 1)

    func storeLayer(_ layer: TreeSitterLanguageLayer, forKey key: UnsafeRawPointer) {
        defer {
            semaphore.signal()
        }
        semaphore.wait()
        store[key] = layer
    }

    func layer(forKey key: UnsafeRawPointer) -> TreeSitterLanguageLayer? {
        defer {
            semaphore.signal()
        }
        semaphore.wait()
        let value = store[key]
        return value
    }

    func removeLayer(forKey key: UnsafeRawPointer) {
        defer {
            semaphore.signal()
        }
        semaphore.wait()
        store.removeValue(forKey: key)
    }

    func removeAll() {
        defer {
            semaphore.signal()
        }
        semaphore.wait()
        store.removeAll()
    }
}
