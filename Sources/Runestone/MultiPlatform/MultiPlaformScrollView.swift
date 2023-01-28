#if os(macOS)
import AppKit
public typealias MultiPlatformScrollView = NSScrollView
#else
import UIKit
public typealias MultiPlatformScrollView = UIScrollView
#endif
