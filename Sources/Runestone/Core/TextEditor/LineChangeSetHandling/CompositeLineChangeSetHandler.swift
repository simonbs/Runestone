struct CompositeLineChangeSetHandler: LineChangeSetHandling {
    private let lineChangeSetHandlers: [LineChangeSetHandling]

    init(_ lineChangeSetHandlers: LineChangeSetHandling...) {
        self.lineChangeSetHandlers = lineChangeSetHandlers
    }

    func handle<LineType: Line>(_ lineChangeSet: LineChangeSet<LineType>) {
        for lineChangeSetHandler in lineChangeSetHandlers {
            lineChangeSetHandler.handle(lineChangeSet)
        }
    }
}
