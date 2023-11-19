@attached(member, names: named(_observableRegistry), named(registerObserver), named(cancelObservation))
@attached(memberAttribute)
@attached(extension, conformances: Observable)
public macro RunestoneObservable() = #externalMacro(
    module: "RunestoneObservationMacros",
    type: "RunestoneObservableMacro"
)

@attached(memberAttribute)
public macro RunestoneObservationIgnored() = #externalMacro(
    module: "RunestoneObservationMacros",
    type: "RunestoneObservableMacro"
)

@attached(accessor, names: named(willSet), named(didSet))
public macro RunestoneObservationTracked() = #externalMacro(
    module: "RunestoneObservationMacros",
    type: "RunestoneObservationTrackedMacro"
)


@attached(member, names: named(_observerRegistry), named(observe))
public macro RunestoneObserver() = #externalMacro(
    module: "RunestoneObservationMacros",
    type: "RunestoneObserverMacro"
)
