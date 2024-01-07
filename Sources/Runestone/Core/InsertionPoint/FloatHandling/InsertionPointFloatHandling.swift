import CoreGraphics

protocol InsertionPointFloatHandling {
    func beginFloatingInsertionPoint(at point: CGPoint)
    func updateFloatingInsertionPoint(at point: CGPoint)
    func endFloatingInsertionPoint()
}
