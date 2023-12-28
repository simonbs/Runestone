@attached(member, names: named(_observableRegistry), named(registerObserver), named(cancelObservation))
@attached(memberAttribute)
@attached(extension, conformances: Observable)
package macro RunestoneObservable() = #externalMacro(
    module: "_RunestoneMacros",
    type: "RunestoneObservableMacro"
)

@attached(accessor, names: named(willSet))
package macro RunestoneObservationIgnored() = #externalMacro(
    module: "_RunestoneMacros",
    type: "RunestoneObservationIgnoredMacro"
)

@attached(accessor, names: named(init), named(get), named(set))
@attached(peer, names: prefixed(`_`))
package macro RunestoneObservationTracked() = #externalMacro(
    module: "_RunestoneMacros",
    type: "RunestoneObservationTrackedMacro"
)


@attached(member, names: named(_observerRegistry), named(observe))
package macro RunestoneObserver() = #externalMacro(
    module: "_RunestoneMacros",
    type: "RunestoneObserverMacro"
)
