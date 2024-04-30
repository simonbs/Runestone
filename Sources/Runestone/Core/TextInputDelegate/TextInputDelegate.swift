protocol TextInputDelegate: AnyObject {
    func selectionWillChange()
    func selectionDidChange()
    func selectionDidChange(sendAnonymously: Bool)
}
