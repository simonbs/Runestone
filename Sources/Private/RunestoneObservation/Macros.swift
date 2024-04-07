@attached(member, names: named(_observableRegistrar))
@attached(memberAttribute)
public macro RunestoneObservable() = #externalMacro(
    module: "_RunestoneMacros",
    type: "RunestoneObservableMacro"
)

@attached(accessor, names: named(willSet))
public macro RunestoneObservationIgnored() = #externalMacro(
    module: "_RunestoneMacros",
    type: "RunestoneObservationIgnoredMacro"
)

@attached(accessor, names: named(init), named(get), named(set))
@attached(peer, names: prefixed(`_`))
public macro RunestoneObservationTracked() = #externalMacro(
    module: "_RunestoneMacros",
    type: "RunestoneObservationTrackedMacro"
)


@attached(member, names: named(_observerRegistrar), named(observe), named(cancelObservation))
public macro RunestoneObserver() = #externalMacro(
    module: "_RunestoneMacros",
    type: "RunestoneObserverMacro"
)
