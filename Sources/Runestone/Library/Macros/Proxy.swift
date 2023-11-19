import Foundation

@attached(accessor)
macro Proxy<T, U>(_ keyPath: ReferenceWritableKeyPath<T, U>) = #externalMacro(
    module: "RunestoneMacros",
    type: "ProxyMacro"
)
