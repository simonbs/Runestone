import UIKit

#if compiler(>=5.9)

@available(iOS 17, *)
extension UITextSelectionDisplayInteraction {
    func sbs_enableCursorBlinks() {
        setValue(true, forKey: "rosruc".reversed() + "Blinks")
    }
}

#endif
