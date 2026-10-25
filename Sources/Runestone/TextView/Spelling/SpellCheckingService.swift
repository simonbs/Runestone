import UIKit

/// The checker is injectable so scheduling and UTF-16 range handling can be tested independently of the system dictionary.
protocol SpellChecking {
    func rangeOfMisspelledWord(in string: String, range: NSRange, startingAt offset: Int, wrap: Bool, language: String) -> NSRange
    func guesses(forWordRange range: NSRange, in string: String, language: String) -> [String]?
}

extension UITextChecker: SpellChecking {}

/// Owns a bounded snapshot of the viewport, never the mutable document. Use only on the main thread, like UITextChecker.
final class SpellCheckingService {
    private(set) var misspelledRanges: [NSRange] = []
    private(set) var generation: UInt = 0

    private let checker: SpellChecking
    private let debounceInterval: TimeInterval
    private var request: Request?
    private static let maximumSnapshotLength = 16_384
    private static let maximumChunkLength = 2_048
    private static let maximumWordLength = 256

    init(checker: SpellChecking = UITextChecker(), debounceInterval: TimeInterval = 0.25) {
        self.checker = checker
        self.debounceInterval = debounceInterval
    }

    func invalidate() {
        generation &+= 1
        request = nil
        misspelledRanges = []
    }

    func schedule(text: NSString, visibleRange: NSRange, language: String, excludedRanges: [NSRange] = [],
                  shouldCheck: ((NSRange) -> Bool)? = nil, completion: @escaping ([NSRange]) -> Void) {
        schedule(text: text, visibleRanges: [visibleRange], language: language, excludedRanges: excludedRanges,
                 shouldCheck: shouldCheck, completion: completion)
    }

    func schedule(text: NSString, visibleRanges: [NSRange], language: String, excludedRanges: [NSRange] = [],
                  shouldCheck: ((NSRange) -> Bool)? = nil, completion: @escaping ([NSRange]) -> Void) {
        invalidate()
        let validRanges = visibleRanges.filter { Self.isValid($0, in: text) && $0.length > 0 }
        guard !validRanges.isEmpty, !language.isEmpty else {
            completion([])
            return
        }
        let chunks = Self.makeChunks(text: text, visibleRanges: validRanges)
        let currentGeneration = generation
        request = Request(chunks: chunks, language: language, excludedRanges: excludedRanges,
                          shouldCheck: shouldCheck, completion: completion)
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceInterval) { [weak self] in
            self?.checkNextBatch(generation: currentGeneration)
        }
    }

    /// Checks the selected word synchronously so correction menus do not depend on debounced viewport results.
    func suggestions(for range: NSRange, in text: NSString, language: String) -> [String] {
        guard range.length > 0, range.length <= Self.maximumWordLength,
              Self.isValid(range, in: text), !language.isEmpty else {
            return []
        }
        // Do not offer corrections for a fragment of a word or a split Unicode sequence.
        if range.location > 0, Self.isWordUnit(text.character(at: range.location - 1)),
           Self.isWordUnit(text.character(at: range.location)) {
            return []
        }
        if NSMaxRange(range) < text.length, Self.isWordUnit(text.character(at: NSMaxRange(range) - 1)),
           Self.isWordUnit(text.character(at: NSMaxRange(range))) {
            return []
        }
        let word = text.substring(with: range)
        let wordRange = NSRange(location: 0, length: range.length)
        guard checker.rangeOfMisspelledWord(in: word, range: wordRange, startingAt: 0, wrap: false, language: language) == wordRange else {
            return []
        }
        return checker.guesses(forWordRange: wordRange, in: word, language: language) ?? []
    }

    private func checkNextBatch(generation expectedGeneration: UInt) {
        guard generation == expectedGeneration, let request else {
            return
        }
        // Yield between chunks and after a fixed number of dictionary calls to avoid monopolizing the main thread.
        var calls = 0
        while request.chunkIndex < request.chunks.count, calls < 16 {
            let chunk = request.chunks[request.chunkIndex]
            let string = chunk.text as NSString
            let range = checker.rangeOfMisspelledWord(in: chunk.text, range: NSRange(location: 0, length: string.length),
                                                      startingAt: request.offset, wrap: false, language: request.language)
            calls += 1
            guard range.location != NSNotFound, range.length > 0, Self.isValid(range, in: string),
                  range.location >= request.offset else {
                request.chunkIndex += 1
                request.offset = 0
                break
            }
            request.offset = NSMaxRange(range)
            let documentRange = NSRange(location: chunk.location + range.location, length: range.length)
            if range.length <= Self.maximumWordLength,
               !request.excludedRanges.contains(where: { Self.intersects(documentRange, exclusion: $0) }),
               request.shouldCheck?(documentRange) ?? true {
                // A delegate may change the document while filtering a candidate.
                guard generation == expectedGeneration else {
                    return
                }
                request.words[documentRange] = string.substring(with: range)
            }
            guard generation == expectedGeneration else {
                return
            }
        }
        if request.chunkIndex == request.chunks.count {
            misspelledRanges = request.words.keys.sorted { $0.location < $1.location }
            self.request = nil
            request.completion(misspelledRanges)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.checkNextBatch(generation: expectedGeneration)
            }
        }
    }

    private static func makeChunks(text: NSString, visibleRanges: [NSRange]) -> [Chunk] {
        // Merge overlapping word-context windows, but do not copy hidden columns between unwrapped lines.
        var mergedRanges: [NSRange] = []
        for range in visibleRanges.sorted(by: { $0.location < $1.location }) {
            if let previous = mergedRanges.last, range.location - NSMaxRange(previous) <= maximumWordLength * 2 {
                mergedRanges[mergedRanges.count - 1] = NSUnionRange(previous, range)
            } else {
                mergedRanges.append(range)
            }
        }
        var chunks: [Chunk] = []
        var remainingBudget = maximumSnapshotLength
        for (index, range) in mergedRanges.enumerated() {
            // Reserve a share for every visible window, including lines following very long unwrapped lines.
            let allowance = remainingBudget / (mergedRanges.count - index)
            let contextStart = max(0, range.location - maximumWordLength)
            let contextEnd = NSMaxRange(range) + min(maximumWordLength, text.length - NSMaxRange(range))
            let length = min(allowance, contextEnd - contextStart)
            let leadingContext = min(range.location - contextStart, max(0, length - range.length) / 2)
            let start = range.location - leadingContext
            let end = min(text.length, start + length)
            chunks.append(contentsOf: makeChunks(text: text, start: start, end: end))
            remainingBudget -= end - start
        }
        return chunks
    }

    private static func makeChunks(text: NSString, start: Int, end: Int) -> [Chunk] {
        var chunks: [Chunk] = []
        var cursor = start
        while cursor < end {
            var chunkStart = cursor
            var chunkEnd = min(end, cursor + maximumChunkLength)
            // Drop partial boundary words, including unusually long identifiers, instead of reporting fragments as misspelled.
            if chunkStart > 0, isWordUnit(text.character(at: chunkStart - 1)) {
                while chunkStart < chunkEnd, isWordUnit(text.character(at: chunkStart)) {
                    chunkStart += 1
                }
            }
            if chunkEnd < text.length, isWordUnit(text.character(at: chunkEnd)) {
                while chunkEnd > chunkStart, isWordUnit(text.character(at: chunkEnd - 1)) {
                    chunkEnd -= 1
                }
            }
            if chunkEnd > chunkStart {
                let range = NSRange(location: chunkStart, length: chunkEnd - chunkStart)
                chunks.append(Chunk(location: chunkStart, text: text.substring(with: range)))
                cursor = chunkEnd
            } else {
                cursor = min(end, cursor + maximumChunkLength)
            }
        }
        return chunks
    }

    private static func isWordUnit(_ unit: unichar) -> Bool {
        // Treat surrogate pairs as word constituents so a chunk can never split them. Apostrophes and hyphens can occur in words.
        if (0xD800...0xDFFF).contains(unit) || unit == 0x27 || unit == 0x2019 || unit == 0x2D {
            return true
        }
        guard let scalar = UnicodeScalar(unit) else {
            return false
        }
        return CharacterSet.letters.contains(scalar) || CharacterSet.decimalDigits.contains(scalar)
            || CharacterSet.nonBaseCharacters.contains(scalar)
    }

    private static func isValid(_ range: NSRange, in text: NSString) -> Bool {
        range.location >= 0 && range.location <= text.length && range.length >= 0 && range.length <= text.length - range.location
    }

    private static func intersects(_ range: NSRange, exclusion: NSRange) -> Bool {
        if exclusion.length == 0 {
            return exclusion.location >= range.location && exclusion.location <= NSMaxRange(range)
        }
        return NSIntersectionRange(range, exclusion).length > 0
    }

    private struct Chunk {
        let location: Int
        let text: String
    }

    private final class Request {
        let chunks: [Chunk]
        let language: String
        let excludedRanges: [NSRange]
        let shouldCheck: ((NSRange) -> Bool)?
        let completion: ([NSRange]) -> Void
        var chunkIndex = 0
        var offset = 0
        var words: [NSRange: String] = [:]

        init(chunks: [Chunk], language: String, excludedRanges: [NSRange], shouldCheck: ((NSRange) -> Bool)?,
             completion: @escaping ([NSRange]) -> Void) {
            self.chunks = chunks
            self.language = language
            self.excludedRanges = excludedRanges
            self.shouldCheck = shouldCheck
            self.completion = completion
        }
    }
}
