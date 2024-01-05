struct InsertionPointViewFactory {
    let insertionPointRenderer: InsertionPointRenderer

    func makeView() -> InsertionPointView {
        InsertionPointView(renderer: insertionPointRenderer)
    }
}
