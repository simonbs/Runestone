import Foundation

public enum Symbol {
    public enum Character {
        public static let lineFeed: Swift.Character = "\n"
        public static let carriageReturn: Swift.Character = "\r"
        public static let carriageReturnLineFeed: Swift.Character = "\r\n"
        public static let lineSeparator: Swift.Character = "\u{2028}"
        public static let tab: Swift.Character = "\t"
        public static let space: Swift.Character = " "
        public static let nonBreakingSpace: Swift.Character = "\u{A0}"
    }

    public static let lineFeed = String(Self.Character.lineFeed)
    public static let carriageReturn = String(Self.Character.carriageReturn)
    public static let carriageReturnLineFeed = String(Self.Character.carriageReturnLineFeed)
    public static let tab = String(Self.Character.tab)
    public static let space = String(Self.Character.space)
}
