import MultiPlatform

extension MultiPlatformColor {
    convenience init(themeColorNamed name: String) {
        let fullName = "theme_" + name
        #if os(iOS)
        self.init(named: fullName, in: .module, compatibleWith: nil)!
        #else
        self.init(named: fullName, bundle: .module)!
        #endif
    }
}
