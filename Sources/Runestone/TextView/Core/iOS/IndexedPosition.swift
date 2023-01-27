#if os(iOS)
import UIKit

final class IndexedPosition: UITextPosition {
    let index: Int

    init(index: Int) {
        self.index = index
    }
}
#endif
