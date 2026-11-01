import Foundation

struct SpellingLanguageRegion: Equatable {
    let range: NSRange
    let languages: [String]
}

/// Scheduling is injectable so debounce, backpressure, and stale completion handling can be tested without sleeps.
protocol SpellingLanguageScheduling: AnyObject {
    func debounce(after delay: TimeInterval, _ work: @escaping () -> Void)
    func infer(_ work: @escaping () -> Void)
    func deliver(_ work: @escaping () -> Void)
}

final class SpellingLanguageScheduler: SpellingLanguageScheduling {
    private let worker = DispatchQueue(label: "Runestone.SpellingLanguage", qos: .utility)
    private var timer: DispatchSourceTimer?

    deinit { timer?.cancel() }

    func debounce(after delay: TimeInterval, _ work: @escaping () -> Void) {
        if timer == nil {
            let timer = DispatchSource.makeTimerSource(queue: .main)
            self.timer = timer
            timer.resume()
        }
        timer?.setEventHandler(handler: work)
        timer?.schedule(deadline: .now() + delay)
    }

    func infer(_ work: @escaping () -> Void) {
        worker.async(execute: work)
    }

    func deliver(_ work: @escaping () -> Void) {
        DispatchQueue.main.async(execute: work)
    }
}

/// Main-thread state owns bounded immutable samples. Only inference operates off the main thread.
final class ParagraphSpellingLanguageService {
    private(set) var regions: [SpellingLanguageRegion] = []
    var onChange: (() -> Void)?

    private let detector: SpellingLanguageDetecting
    private let scheduler: SpellingLanguageScheduling
    private let debounceInterval: TimeInterval
    private var generation: UInt = 0
    private var workerActive = false
    private var pending: Request?
    private var current: Request?
    private var cache: [CacheEntry] = []
    private static let maximumCacheCount = 64

    init(detector: SpellingLanguageDetecting = NaturalLanguageSpellingDetector(),
         scheduler: SpellingLanguageScheduling = SpellingLanguageScheduler(), debounceInterval: TimeInterval = 0.3) {
        self.detector = detector
        self.scheduler = scheduler
        self.debounceInterval = debounceInterval
    }

    func update(text: NSString, visibleRanges: [NSRange], availableLanguages: [String]) {
        let snapshots = Self.snapshots(text: text, visibleRanges: visibleRanges)
        guard current?.snapshots != snapshots || current?.availableLanguages != availableLanguages else {
            return
        }
        generation &+= 1
        let cached = snapshots.compactMap { snapshot -> CacheEntry? in
            guard let entry = cache.last(where: { $0.snapshot.text == snapshot.text && $0.availableLanguages == availableLanguages }) else {
                return nil
            }
            return CacheEntry(snapshot: snapshot, availableLanguages: availableLanguages, language: entry.language)
        }
        let request = Request(generation: generation, snapshots: snapshots, availableLanguages: availableLanguages, cachedResults: cached)
        current = request
        pending = nil
        regions = snapshots.compactMap { snapshot in
            guard let cached = cachedLanguage(for: snapshot), availableLanguages.contains(cached) else {
                return nil
            }
            return SpellingLanguageRegion(range: snapshot.range, languages: [cached])
        }
        guard !snapshots.isEmpty else {
            return
        }
        // A cache hit requires exact text and available dictionaries; retained languages for edited paragraphs
        // are provisional until fresh inference finishes, rather than a reason to skip that inference.
        if cached.count == snapshots.count {
            return
        }
        let expectedGeneration = request.generation
        scheduler.debounce(after: debounceInterval) { [weak self] in
            guard let self = self, let latest = self.current, latest.generation == expectedGeneration else {
                return
            }
            self.pending = latest
            self.startPendingIfPossible()
        }
    }

    func invalidate(preservingLanguages: Bool = false, preservingRegions: Bool = false) {
        generation &+= 1
        current = nil
        pending = nil
        if !preservingRegions || !preservingLanguages {
            regions = []
        }
        if !preservingLanguages {
            cache = []
        }
        // An already running worker keeps its slot until delivery; a replacement cannot run alongside it.
    }

    func languages(for range: NSRange, fallback: [String]) -> [String] {
        regions.first { $0.range.location <= range.location && NSMaxRange(range) <= NSMaxRange($0.range) }?.languages ?? fallback
    }

    static func detectedLanguage(in text: String, availableLanguages: [String],
                                 detector: SpellingLanguageDetecting = NaturalLanguageSpellingDetector()) -> String? {
        guard let text = SpellingProseSample.cleaned(text), isProse(text) else {
            return nil
        }
        let hypotheses = detector.hypotheses(for: text).filter { $0.value.isFinite }.sorted { $0.value > $1.value }
        guard let first = hypotheses.first, first.value >= 0.9,
              first.value - (hypotheses.dropFirst().first?.value ?? 0) >= 0.2 else {
            return nil
        }
        return SpellingLanguageResolver.resolve(explicitLanguage: nil, keyboardLanguages: [first.key],
                                                preferredLanguages: [], availableLanguages: availableLanguages)
            .first.flatMap { resolved in
                let detectedBase = first.key.replacingOccurrences(of: "-", with: "_").split(separator: "_").first?.lowercased()
                return resolved.split(separator: "_").first?.lowercased() == detectedBase ? resolved : nil
            }
    }

    static func isProse(_ text: String) -> Bool {
        let scalars = text.unicodeScalars
        guard !scalars.isEmpty else {
            return false
        }
        var letters = 0
        var symbols = 0
        let prosePunctuation = CharacterSet(charactersIn: ".,!?;:'’\"–—-()“”")
        for scalar in scalars {
            if CharacterSet.letters.contains(scalar) { letters += 1 }
            if !CharacterSet.letters.contains(scalar), !CharacterSet.whitespacesAndNewlines.contains(scalar),
               !prosePunctuation.contains(scalar) { symbols += 1 }
        }
        guard letters >= 40, Double(letters) / Double(scalars.count) >= 0.55,
              Double(symbols) / Double(scalars.count) <= 0.15 else {
            return false
        }
        let words = text.split { $0.isWhitespace }
        guard words.count >= 8 else {
            return false
        }
        // Programming-shaped lines can contain mostly English identifiers. Keep their fallback dictionaries.
        return !text.contains("```") && !text.contains("{") && !text.contains("}") && !text.contains("=>")
            && !text.contains(" = ") && !text.contains("https://") && !text.contains("http://")
    }
}

private extension ParagraphSpellingLanguageService {
    struct Request {
        let generation: UInt
        let snapshots: [SpellingParagraphSnapshot]
        let availableLanguages: [String]
        let cachedResults: [CacheEntry]
    }

    struct CacheEntry {
        let snapshot: SpellingParagraphSnapshot
        let availableLanguages: [String]
        let language: String?
    }

    func cachedLanguage(for snapshot: SpellingParagraphSnapshot) -> String? {
        if let exact = cache.last(where: { $0.snapshot.text == snapshot.text }) {
            return exact.language
        }
        // Keep established paragraph language during a small local edit, but not wholesale replacement.
        return cache.last { entry in
            entry.snapshot.range.location == snapshot.range.location && Self.isSimilar(entry.snapshot.text, snapshot.text)
        }?.language
    }

    static func isSimilar(_ first: String, _ second: String) -> Bool {
        let left = Array(first.utf16)
        let right = Array(second.utf16)
        let sharedPrefix = zip(left, right).prefix { $0 == $1 }.count
        let sharedSuffix = zip(left.reversed(), right.reversed()).prefix { $0 == $1 }.count
        return sharedPrefix + sharedSuffix >= max(left.count, right.count) / 2
    }

    func startPendingIfPossible() {
        guard !workerActive, let request = pending else {
            return
        }
        pending = nil
        workerActive = true
        let detector = self.detector
        let scheduler = self.scheduler
        scheduler.infer { [weak self] in
            let results = request.snapshots.map { snapshot in
                if let cached = request.cachedResults.first(where: { $0.snapshot == snapshot }) {
                    return cached
                }
                return CacheEntry(snapshot: snapshot, availableLanguages: request.availableLanguages,
                                  language: Self.detectedLanguage(in: snapshot.text, availableLanguages: request.availableLanguages,
                                                                  detector: detector))
            }
            scheduler.deliver { [weak self] in
                self?.finish(request, results: results)
            }
        }
    }

    func finish(_ request: Request, results: [CacheEntry]) {
        workerActive = false
        if current?.generation == request.generation {
            for result in results {
                cache.removeAll { $0.snapshot.range.location == result.snapshot.range.location }
                cache.append(result)
            }
            if cache.count > Self.maximumCacheCount { cache.removeFirst(cache.count - Self.maximumCacheCount) }
            let updated = results.compactMap { result in
                result.language.map { SpellingLanguageRegion(range: result.snapshot.range, languages: [$0]) }
            }
            if updated != regions {
                regions = updated
                onChange?()
            }
        }
        startPendingIfPossible()
    }
}

extension ParagraphSpellingLanguageService {
    static func snapshots(text: NSString, visibleRanges: [NSRange]) -> [SpellingParagraphSnapshot] {
        var builder = SpellingParagraphSnapshotBuilder(text: text)
        return builder.snapshots(visibleRanges: visibleRanges)
    }
}
