import Foundation

protocol TextInputDelegate: AnyObject {
    func selectionWillChange()
    func selectionDidChange()
}
