final class CompositeRenderer: Renderer {
    private let renderers: [Renderer]

    init(renderers: [Renderer]) {
        self.renderers = renderers
    }

    func render() {
        for renderer in renderers {
            renderer.render()
        }
    }
}
