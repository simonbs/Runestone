import Foundation

protocol UndoManagable {
    func beginUndoGrouping()
    func endUndoGrouping()
    func setActionName(_ actionName: String)
    func registerUndo<T: AnyObject>(withTarget target: T, handler: @escaping (T) -> Void)
}
