extension String {
    func replacingAllLineEndings(with preferredLineEnding: LineEnding) -> String {
        // Ensure all line endings match our preferred line endings.
        var result = self
        let lineEndingsToReplace: [LineEnding] = [.crlf, .cr, .lf].filter { $0 != preferredLineEnding }
        for lineEnding in lineEndingsToReplace {
            result = result.replacingOccurrences(of: lineEnding.symbol, with: preferredLineEnding.symbol)
        }
        return result
    }
}
