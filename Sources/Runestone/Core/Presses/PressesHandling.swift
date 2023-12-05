#if os(iOS)
import UIKit

protocol PressesHandling {
    func handlePressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?)
}
#endif
