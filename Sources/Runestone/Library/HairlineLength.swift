import UIKit

#if !os(xrOS)
let hairlineLength = 1 / UIScreen.main.scale
#else
let hairlineLength: CGFloat = 1
#endif
