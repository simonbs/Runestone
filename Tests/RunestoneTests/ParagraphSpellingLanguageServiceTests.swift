import Foundation
@testable import Runestone
import XCTest

final class ParagraphSpellingLanguageServiceTests: XCTestCase {
    private let english = "This paragraph explains how the editor checks spelling and chooses the appropriate dictionary for every reader."
    private let danish = "Dette afsnit forklarer hvordan editoren kontrollerer stavningen og vælger den rigtige ordbog til alle sine læsere."
    private let fallback = ["en_US", "da_DK"]
    private let available = ["en_US", "da_DK", "fr_FR"]

    func testConfidentParagraphNarrowsToAnAvailableLanguageOutsideTheKeyboardFallback() {
        let fixture = DetectionFixture { _ in ["fr": 0.99] }
        fixture.update(english, available: available)
        let range = (english as NSString).range(of: "paragraph")
        XCTAssertEqual(fixture.service.languages(for: range, fallback: fallback), fallback)

        fixture.scheduler.complete()

        XCTAssertEqual(fixture.service.languages(for: range, fallback: fallback), ["fr_FR"])
        XCTAssertEqual(fixture.detector.texts.count, 1)
    }

    func testDetectedBaseLanguageKeepsThePreferredAvailableDictionaryDialect() {
        let fixture = DetectionFixture { _ in ["en": 0.99] }
        fixture.update(english, available: ["en_GB", "en_US", "da_DK"])
        fixture.scheduler.complete()

        XCTAssertEqual(fixture.service.languages(for: (english as NSString).range(of: "paragraph"), fallback: ["en_GB", "da_DK"]), ["en_GB"])
    }

    func testMixedParagraphsUseIndependentDictionariesAndDocumentUTF16Ranges() {
        let fixture = DetectionFixture { text in text.contains("Dette") ? ["da": 0.99] : ["en": 0.99] }
        let text = "👋 " + english + "\r\n\r\n" + danish
        fixture.update(text, available: available)
        fixture.scheduler.complete()
        let string = text as NSString

        XCTAssertEqual(fixture.service.languages(for: string.range(of: "paragraph"), fallback: fallback), ["en_US"])
        XCTAssertEqual(fixture.service.languages(for: string.range(of: "afsnit"), fallback: fallback), ["da_DK"])
    }

    func testUncertainAndUnavailableLanguageResultsUseAllFallbackDictionaries() {
        let results: [[String: Double]] = [[:], ["en": 0.55, "da": 0.45], ["en": 0.82, "da": 0.79], ["zz": 0.99]]
        for hypotheses in results {
            let fixture = DetectionFixture { _ in hypotheses }
            fixture.update(english, available: available)
            fixture.scheduler.complete()

            XCTAssertEqual(fixture.service.languages(for: (english as NSString).range(of: "paragraph"), fallback: fallback), fallback)
        }
    }

    func testShortAndCodeHeavyTextDoNotUseAConfidentButUnreliableGuess() {
        let samples = ["Hello", String(repeating: "let x = foo(a[0], b: 42) { return x != nil }; // `code`\n", count: 5)]
        for text in samples {
            let fixture = DetectionFixture { _ in ["fr": 0.99] }
            fixture.update(text, available: available)
            fixture.scheduler.complete()

            XCTAssertEqual(fixture.service.languages(for: NSRange(location: 0, length: min(3, text.utf16.count)), fallback: fallback), fallback)
            XCTAssertTrue(fixture.detector.texts.isEmpty, "Do not send insufficient prose to the recognizer.")
        }
    }

    func testRapidUpdatesCoalesceWhileAnInferenceIsRunningAndCannotPublishStaleResults() {
        let fixture = DetectionFixture { _ in ["fr": 0.99] }
        var publications = 0
        fixture.service.onChange = { publications += 1 }
        fixture.update(english, available: available)
        fixture.scheduler.runDebounced()
        XCTAssertEqual(fixture.scheduler.inferences.count, 1)

        let skipped = danish + " Denne ændring bliver straks erstattet af en nyere udgave."
        fixture.update(skipped, available: available)
        fixture.scheduler.runDebounced()
        let newest = english + " The latest paragraph must be the only pending inference that is actually evaluated."
        fixture.update(newest, available: available)
        fixture.scheduler.runDebounced()
        XCTAssertEqual(fixture.scheduler.inferences.count, 1, "Only one background inference may be in flight.")

        let publicationsBeforeCompletion = publications
        fixture.scheduler.runInference()
        fixture.scheduler.runDeliveries()
        XCTAssertEqual(publications, publicationsBeforeCompletion, "A superseded document must not publish its detected language.")
        fixture.scheduler.complete()

        XCTAssertFalse(fixture.detector.texts.contains(skipped))
        XCTAssertTrue(fixture.detector.texts.contains(newest))
        XCTAssertEqual(fixture.service.languages(for: (newest as NSString).range(of: "latest"), fallback: fallback), ["fr_FR"])
    }

    func testInvalidationDiscardsInFlightDetectionAndAllowsANewDocument() {
        let fixture = DetectionFixture { text in text.contains("Dette") ? ["da": 0.99] : ["en": 0.99] }
        var publications = 0
        fixture.service.onChange = { publications += 1 }
        fixture.update(english, available: available)
        fixture.scheduler.runDebounced()
        fixture.service.invalidate()
        let publicationsBeforeCompletion = publications
        fixture.scheduler.runInference()
        fixture.scheduler.runDeliveries()

        XCTAssertEqual(publications, publicationsBeforeCompletion)
        XCTAssertEqual(fixture.service.languages(for: (english as NSString).range(of: "paragraph"), fallback: fallback), fallback)
        fixture.update(danish, available: available)
        fixture.scheduler.complete()
        XCTAssertEqual(fixture.service.languages(for: (danish as NSString).range(of: "afsnit"), fallback: fallback), ["da_DK"])
    }

    func testCompletedLanguageRemainsAvailableWhileSameParagraphIsPendingThenUncertaintyClearsIt() {
        let fixture = DetectionFixture { _ in ["en": 0.99] }
        fixture.update(english, available: available)
        fixture.scheduler.complete()
        fixture.detector.hypotheses = { _ in [:] }
        let edited = english + " A further sentence adds some more context to the same paragraph."
        fixture.update(edited, available: available)
        let word = (edited as NSString).range(of: "paragraph")

        XCTAssertEqual(fixture.service.languages(for: word, fallback: fallback), ["en_US"])
        fixture.scheduler.complete()
        XCTAssertEqual(fixture.service.languages(for: word, fallback: fallback), fallback)
    }

    func testNewParagraphUsesFallbackWhilePendingAndUnchangedTextReusesCompletedInference() {
        let fixture = DetectionFixture { _ in ["en": 0.99] }
        fixture.update(english, available: available)
        fixture.scheduler.complete()
        let detectedCount = fixture.detector.texts.count
        fixture.update(english, available: available)
        fixture.scheduler.complete()
        XCTAssertEqual(fixture.detector.texts.count, detectedCount, "Unchanged paragraphs must reuse completed detection.")

        let text = english + "\n\n" + danish
        fixture.update(text, available: available)
        XCTAssertEqual(fixture.service.languages(for: (text as NSString).range(of: "afsnit"), fallback: fallback), fallback)
    }

    func testEditingOrAddingOneParagraphReusesEveryUnchangedResultIncludingUncertainty() {
        let fixture = DetectionFixture { text in text.contains("Dette") ? [:] : ["en": 0.99] }
        fixture.update(english + "\n\n" + danish, available: available)
        fixture.scheduler.complete()
        XCTAssertEqual(fixture.detector.texts.count, 2)

        let edited = english.replacingOccurrences(of: "editor", with: "reader")
        fixture.update(edited + "\n\n" + danish, available: available)
        fixture.scheduler.complete()
        XCTAssertEqual(fixture.detector.texts.count, 3, "Editing one paragraph must not recognize another unchanged paragraph again.")
        XCTAssertEqual(fixture.detector.texts.last, edited)

        let added = "This additional paragraph explains a different feature of the document editor for its readers."
        fixture.update(edited + "\n\n" + danish + "\n\n" + added, available: available)
        fixture.scheduler.complete()
        XCTAssertEqual(fixture.detector.texts.count, 4, "A cached uncertain result must also avoid repeated background inference.")
        XCTAssertEqual(fixture.detector.texts.last, added)
    }

    func testInvalidationCanPreserveCompletedParagraphsButAResetClearsThem() {
        let fixture = DetectionFixture { _ in ["en": 0.99] }
        fixture.update(english, available: available)
        fixture.scheduler.complete()
        let range = (english as NSString).range(of: "paragraph")
        fixture.service.invalidate(preservingLanguages: true)
        fixture.update(english, available: available)
        XCTAssertEqual(fixture.service.languages(for: range, fallback: fallback), ["en_US"])
        XCTAssertEqual(fixture.detector.texts.count, 1)

        fixture.service.invalidate()
        XCTAssertEqual(fixture.service.languages(for: range, fallback: fallback), fallback)
    }
}

final class DetectionFixture {
    let detector: ControlledLanguageDetector
    let scheduler = ControlledLanguageScheduler()
    let service: ParagraphSpellingLanguageService

    init(hypotheses: @escaping (String) -> [String: Double]) {
        let detector = ControlledLanguageDetector(hypotheses: hypotheses)
        self.detector = detector
        service = ParagraphSpellingLanguageService(detector: detector, scheduler: scheduler, debounceInterval: 0)
    }

    func update(_ text: String, available: [String]) {
        service.update(text: text as NSString, visibleRanges: [NSRange(location: 0, length: text.utf16.count)], availableLanguages: available)
    }
}

final class ControlledLanguageDetector: SpellingLanguageDetecting {
    var texts: [String] = []
    var hypotheses: (String) -> [String: Double]

    init(hypotheses: @escaping (String) -> [String: Double]) {
        self.hypotheses = hypotheses
    }

    func hypotheses(for text: String) -> [String: Double] {
        texts.append(text)
        return hypotheses(text)
    }
}

final class ControlledLanguageScheduler: SpellingLanguageScheduling {
    private var debounced: [() -> Void] = []
    private(set) var inferences: [() -> Void] = []
    private var deliveries: [() -> Void] = []

    func debounce(after interval: TimeInterval, _ work: @escaping () -> Void) {
        debounced.append(work)
    }

    func infer(_ work: @escaping () -> Void) {
        inferences.append(work)
    }

    func deliver(_ work: @escaping () -> Void) {
        deliveries.append(work)
    }

    func runDebounced() {
        let work = debounced
        debounced.removeAll()
        work.forEach { $0() }
    }

    func runInference() {
        if !inferences.isEmpty {
            inferences.removeFirst()()
        }
    }

    func runDeliveries() {
        let work = deliveries
        deliveries.removeAll()
        work.forEach { $0() }
    }

    func complete(file: StaticString = #filePath, line: UInt = #line) {
        runDebounced()
        var iterations = 0
        while !inferences.isEmpty || !deliveries.isEmpty {
            iterations += 1
            guard iterations < 100 else {
                XCTFail("Language inference did not finish its bounded pending work", file: file, line: line)
                return
            }
            runInference()
            runDeliveries()
            runDebounced()
        }
    }
}
