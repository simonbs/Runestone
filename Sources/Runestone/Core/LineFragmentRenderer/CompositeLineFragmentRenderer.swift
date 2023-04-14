final class CompositeLineFragmentRenderer: LineFragmentRenderer {
    private let renderers: [LineFragmentRenderer]

    init(renderers: [LineFragmentRenderer]) {
        self.renderers = renderers
    }

    func render() {
        for renderer in renderers {
            renderer.render()
        }
    }
}
