struct ContentSizeUpdatingLineChangeSetHandler<LineManagerType: LineManaging>: LineChangeSetHandling {
    let contentSizeService: ContentSizeService<LineManagerType>

    func handle<LineType: Line>(_ lineChangeSet: LineChangeSet<LineType>) {
        for line in lineChangeSet.removedLines {
            contentSizeService.removeLine(withID: line.id)
        }
    }
}
