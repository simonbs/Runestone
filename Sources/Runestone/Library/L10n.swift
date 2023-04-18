// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

import Foundation

// swiftlint:disable superfluous_disable_command file_length implicit_return prefer_self_in_static_references

// MARK: - Strings

// swiftlint:disable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:disable nesting type_body_length type_name vertical_whitespace_opening_braces
internal enum L10n {
  internal enum Menu {
    internal enum ItemTitle {
      /// Replace
      internal static let replace = L10n.tr("Localizable", "menu.item_title.replace", fallback: "Replace")
    }
  }
  internal enum Undo {
    internal enum ActionName {
      /// Move Lines Down
      internal static let moveLinesDown = L10n.tr("Localizable", "undo.action_name.move_lines_down", fallback: "Move Lines Down")
      /// Move Lines Up
      internal static let moveLinesUp = L10n.tr("Localizable", "undo.action_name.move_lines_up", fallback: "Move Lines Up")
      /// Replace All
      internal static let replaceAll = L10n.tr("Localizable", "undo.action_name.replace_all", fallback: "Replace All")
      /// Typing
      internal static let typing = L10n.tr("Localizable", "undo.action_name.typing", fallback: "Typing")
    }
  }
}
// swiftlint:enable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:enable nesting type_body_length type_name vertical_whitespace_opening_braces

// MARK: - Implementation Details

extension L10n {
  private static func tr(_ table: String, _ key: String, _ args: CVarArg..., fallback value: String) -> String {
    let format = BundleToken.bundle.localizedString(forKey: key, value: value, table: table)
    return String(format: format, locale: Locale.current, arguments: args)
  }
}

// swiftlint:disable convenience_type
private final class BundleToken {
  static let bundle: Bundle = {
    #if SWIFT_PACKAGE
    return Bundle.module
    #else
    return Bundle(for: BundleToken.self)
    #endif
  }()
}
// swiftlint:enable convenience_type
