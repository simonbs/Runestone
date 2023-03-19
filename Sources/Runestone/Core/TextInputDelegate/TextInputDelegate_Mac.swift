#if os(macOS)
final class TextInputDelegate_Mac: TextInputDelegate {
    func selectionWillChange() {}

    func selectionDidChange() {}

    func selectionDidChange(sendAnonymously: Bool) {}
}
#endif
