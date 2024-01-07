protocol TextNavigationLocationProviding {
    func location(
        from sourceLocation: Int,
        inDirection direction: TextNavigationDirection,
        offset: Int
    ) -> Int?
}
