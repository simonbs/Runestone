#if os(iOS)
import UIKit

final class RunestoneUITextPosition: UITextPosition {
    let location: Int

    init(_ location: Int) {
        self.location = location
    }
}
#endif
