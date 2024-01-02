protocol LineChangeSetHandling {
    func handle<LineType: Line>(_ lineChangeSet: LineChangeSet<LineType>)
}
