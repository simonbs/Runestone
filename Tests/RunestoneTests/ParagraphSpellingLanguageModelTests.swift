import Foundation
@testable import Runestone
import XCTest

/// Real-model checks complement the injected-detector contract tests. Scores are
/// diagnostics, never exact expectations: Apple can update its language models.
final class ParagraphSpellingLanguageModelTests: XCTestCase {
    private let availableLanguages = ["en_US", "da_DK", "es_ES"]

    func testRecognizesEnglishREADMEAndDanishProseRegardlessOfKeyboardFallback() {
        assertDetected(englishProse, equals: "en_US")
        assertDetected(danishProse, equals: "da_DK")
    }

    func testRecognizesREADMEProseAroundInlineCodeAndMarkdownLinkTargets() {
        let markdown = """
        Please refer to the [Getting Started](https://github.com/simonbs/Runestone/blob/main/Documentation/GettingStarted.md)
        documentation for instructions on using `Runestone.TextView` in your application.
        The public types provide everything needed to display and edit a document efficiently.
        """
        assertDetected(markdown, equals: "en_US")
        let danishMarkdown = """
        Læs [dokumentationen](https://github.com/simonbs/Runestone/blob/main/Documentation/GettingStarted.md)
        for at komme i gang med at bruge `Runestone.TextView` i din app.
        Her finder du en beskrivelse af alle funktionerne og en grundig vejledning i at redigere dokumenter.
        """
        assertDetected(danishMarkdown, equals: "da_DK")
    }

    func testRecognizesSpanishWithoutAnEnglishOrDanishFallbackBias() {
        assertDetected(spanishProse, equals: "es_ES")
    }

    func testShortTextAndCodeLeaveDictionaryChoiceToFallbackPolicy() {
        assertDetected("public types", equals: nil)
        assertDetected("func documentation(for type: PublicType) -> String { return project.performance.description }", equals: nil)
    }

    func testClearlyMixedSentencesDoNotForceOneDictionaryOnBothLanguages() {
        // The whole-paragraph model can confidently misclassify mixed prose.
        // Sentence disagreement must preserve the caller's automatic fallback.
        let mixed = """
        This paragraph explains the editor and its documentation for every user of the application.
        Denne del beskriver stavekontrollen og viser, hvordan forskellige sprog kan bruges i samme dokument.
        """
        assertDetected(mixed, equals: nil)
    }

    func testLateLanguageSwitchDoesNotForceTheOpeningLanguageOnTheLastSentence() {
        let mixed = """
        This paragraph explains the editor and its documentation for every user of the application.
        The public types provide everything needed to display and edit a document efficiently.
        The application keeps the selected language with each file so that the same preference is restored later.
        When judging performance, consider the size of the document and how much text is visible on the screen.
        Denne del beskriver stavekontrollen og viser, hvordan forskellige sprog kan bruges i samme dokument.
        """
        assertDetected(mixed, equals: nil)
    }

    func testUnsupportedRecognizedLanguageDoesNotChooseAnUnrelatedDictionary() {
        let detector = NaturalLanguageSpellingDetector()
        let detected = ParagraphSpellingLanguageService.detectedLanguage(
            in: spanishProse, availableLanguages: ["en_US", "da_DK"], detector: detector
        )
        XCTAssertNil(detected, diagnostic(for: spanishProse, detector: detector))
    }

    /// Run alone in a fresh serial Release test runner for first-use evidence.
    /// No absolute latency assertions: OS model initialization and device load vary.
    func testPerformanceFirstUseWarmRecognitionAndBoundedSamples() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["RUNESTONE_PERFORMANCE"] == "1")
        let firstStart = DispatchTime.now().uptimeNanoseconds
        let detector = NaturalLanguageSpellingDetector()
        let first = ParagraphSpellingLanguageService.detectedLanguage(
            in: englishProse, availableLanguages: availableLanguages, detector: detector
        )
        let firstUse = milliseconds(since: firstStart)
        XCTAssertEqual(first, "en_US")
        print("PARAGRAPH_SPELLING_FIRST_USE \(firstUse) ms; cold only when selected alone in a fresh process")

        let largeParagraph = String(repeating: englishProse.replacingOccurrences(of: "\n", with: " ") + " ", count: 5_000) as NSString
        let viewport = NSRange(location: largeParagraph.length / 2, length: 10_000)
        var snapshotSamples: [Double] = []
        var snapshots: [SpellingParagraphSnapshot] = []
        for _ in 0..<30 {
            let start = DispatchTime.now().uptimeNanoseconds
            snapshots = ParagraphSpellingLanguageService.snapshots(text: largeParagraph, visibleRanges: [viewport])
            snapshotSamples.append(milliseconds(since: start))
        }
        XCTAssertFalse(snapshots.isEmpty)
        XCTAssertLessThanOrEqual(snapshots.count, 16)
        XCTAssertLessThanOrEqual(snapshots.reduce(0) { $0 + $1.text.utf16.count }, 16_384)
        XCTAssertTrue(snapshots.allSatisfy { $0.text.utf16.count <= 2_048 })
        let snapshotRecord: [String: Any] = [
            "documentUTF16": largeParagraph.length, "visibleUTF16": viewport.length,
            "snapshotUTF16": snapshots.reduce(0) { $0 + $1.text.utf16.count }, "samplesMs": snapshotSamples
        ]
        let snapshotData = try JSONSerialization.data(withJSONObject: snapshotRecord, options: [.sortedKeys])
        print("PARAGRAPH_SPELLING_SNAPSHOTS \(try XCTUnwrap(String(data: snapshotData, encoding: .utf8)))")
        let boundedParagraph = try XCTUnwrap(snapshots.first).text
        let fixtures = [("english", englishProse, "en_US"), ("danish", danishProse, "da_DK"),
                        ("spanish", spanishProse, "es_ES"), ("bounded-2048", boundedParagraph, "en_US")]
        for (name, text, expected) in fixtures {
            var samples: [Double] = []
            for _ in 0..<30 {
                let start = DispatchTime.now().uptimeNanoseconds
                let result = ParagraphSpellingLanguageService.detectedLanguage(
                    in: text, availableLanguages: availableLanguages, detector: detector
                )
                samples.append(milliseconds(since: start))
                XCTAssertEqual(result, expected, "Performance work must still produce the correct language")
            }
            let sorted = samples.sorted()
            let record: [String: Any] = [
                "fixture": name, "utf16": text.utf16.count,
                "samplesMs": samples, "medianMs": sorted[sorted.count / 2],
                "p95Ms": sorted[Int(ceil(Double(sorted.count) * 0.95)) - 1], "maximumMs": sorted[sorted.count - 1]
            ]
            let data = try JSONSerialization.data(withJSONObject: record, options: [.sortedKeys])
            print("PARAGRAPH_SPELLING_WARM \(try XCTUnwrap(String(data: data, encoding: .utf8)))")
        }
    }

    private func assertDetected(_ text: String, equals expected: String?, file: StaticString = #filePath, line: UInt = #line) {
        let detector = NaturalLanguageSpellingDetector()
        let detected = ParagraphSpellingLanguageService.detectedLanguage(
            in: text, availableLanguages: availableLanguages, detector: detector
        )
        XCTAssertEqual(detected, expected, diagnostic(for: text, detector: detector), file: file, line: line)
    }

    private func diagnostic(for text: String, detector: SpellingLanguageDetecting) -> String {
        let hypotheses = detector.hypotheses(for: text)
            .map { "\($0.key):\($0.value)" }.sorted().joined(separator: ", ")
        return "OS \(ProcessInfo.processInfo.operatingSystemVersionString); hypotheses [\(hypotheses)]"
    }

    private func milliseconds(since start: UInt64) -> Double {
        Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
    }
}

private let englishProse = """
The documentation of all public types is available online. Runestone was built to be fast.
When judging the performance of Runestone, consider the size of the document and how much text is visible on the screen.
"""

private let danishProse = """
Dokumentationen beskriver alle offentlige typer og forklarer, hvordan programmet bruges. Denne tekst er skrevet på dansk.
Når du vurderer programmets ydeevne, skal du overveje dokumentets størrelse og hvor meget tekst der vises på skærmen.
"""

private let spanishProse = """
La documentación describe todas las funciones del programa y explica cómo utilizarlas.
Este texto está escrito en español y contiene información sobre la edición de documentos.
Para evaluar el rendimiento del editor, hay que considerar el tamaño del archivo y la cantidad de texto visible en la pantalla.
"""
