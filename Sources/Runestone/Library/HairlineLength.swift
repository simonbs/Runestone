import UIKit

#if !os(visionOS)
let hairlineLength = 1 / UIScreen.main.scale
#else
let hairlineLength: CGFloat = 1
#endif
