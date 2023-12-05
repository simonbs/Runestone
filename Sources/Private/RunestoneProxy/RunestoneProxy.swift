import Foundation

@attached(accessor)
package macro RunestoneProxy<T, U>(_ keyPath: ReferenceWritableKeyPath<T, U>) = #externalMacro(
    module: "_RunestoneMacros",
    type: "RunestoneProxyMacro"
)
