@attached(member, names: named(_observableRegistry), named(registerObserver), named(cancelObservation))
@attached(memberAttribute)
@attached(extension, conformances: Observable)
package macro RunestoneObservable() = #externalMacro(
    module: "_RunestoneMacros",
    type: "RunestoneObservableMacro"
)

@attached(memberAttribute)
package macro RunestoneObservationIgnored() = #externalMacro(
    module: "_RunestoneMacros",
    type: "RunestoneObservableMacro"
)

@attached(accessor, names: named(willSet), named(didSet))
package macro RunestoneObservationTracked() = #externalMacro(
    module: "_RunestoneMacros",
    type: "RunestoneObservationTrackedMacro"
)


@attached(member, names: named(_observerRegistry), named(observe))
package macro RunestoneObserver() = #externalMacro(
    module: "_RunestoneMacros",
    type: "RunestoneObserverMacro"
)
