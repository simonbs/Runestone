#if os(macOS)
import AppKit

public typealias MultiPlatformColor = NSColor
public typealias MultiPlatformFont = NSFont
#elseif os(iOS)
import UIKit

public typealias MultiPlatformColor = UIColor
public typealias MultiPlatformFont = UIFont
#endif
