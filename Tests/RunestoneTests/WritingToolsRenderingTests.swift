@testable import Runestone
import UIKit
import XCTest

#if compiler(>=6.0.3) && (!os(visionOS) || compiler(>=6.1))
@available(iOS 18.2, visionOS 2.4, *)
@MainActor
final class WritingToolsRenderingTests: XCTestCase {
    private var window: UIWindow?

    func testDetachedEditorDeclinesAnimationPreviewWithoutCrashing() throws {
        let view = TextView(frame: CGRect(x: 0, y: 0, width: 260, height: 160))
        view.text = "Detached editor text"
        view.layoutIfNeeded()
        let input = try textInput(in: view)
        input.layoutLines(toLocation: input.string.length)
        let interaction = makeInteraction(in: input)
        let context = try requestContext(from: interaction)
        let completion = expectation(description: "Detached preview request completes")
        interaction.writingToolsCoordinator(interaction.coordinator,
                                            requestsPreviewFor: .anticipate,
                                            of: NSRange(location: 0, length: input.string.length),
                                            in: context) { preview in
            XCTAssertNil(preview)
            completion.fulfill()
        }
        wait(for: [completion], timeout: 1)
    }

    func testWrappedTextGeometryAndPreviewRespectInsetsGutterAndViewport() throws {
        let view = try makeTextView(text: String(repeating: "A long paragraph with several words. ", count: 100))
        let input = try textInput(in: view)
        let interaction = makeInteraction(in: input)
        let context = try requestContext(from: interaction)
        let range = NSRange(location: 0, length: (view.text as NSString).length)
        var paths: [UIBezierPath] = []
        interaction.writingToolsCoordinator(interaction.coordinator, requestsBoundingBezierPathsFor: range, in: context) { paths = $0 }
        XCTAssertGreaterThan(paths.count, 2, "Wrapped text must produce individual line regions for the system effects.")
        let first = try XCTUnwrap(paths.first?.bounds)
        XCTAssertEqual(first.minX, input.caretRect(at: 0).minX, accuracy: 0.5)
        XCTAssertEqual(first.minX, view.gutterWidth + view.textContainerInset.left, accuracy: 0.5)
        XCTAssertEqual(first.minY, view.textContainerInset.top, accuracy: 0.5)
        for (previous, next) in zip(paths, paths.dropFirst()) {
            XCTAssertLessThan(previous.bounds.minY, next.bounds.minY)
            XCTAssertLessThanOrEqual(previous.bounds.maxY, next.bounds.minY + 0.5)
        }

        var preview: UITargetedPreview?
        interaction.writingToolsCoordinator(interaction.coordinator, requestsPreviewFor: .anticipate, of: range, in: context) { preview = $0 }
        let result = try XCTUnwrap(preview)
        let imageView = try XCTUnwrap(result.view as? UIImageView)
        let image = try XCTUnwrap(imageView.image)
        XCTAssertTrue(input.viewport.contains(imageView.frame))
        XCTAssertLessThanOrEqual(image.size.width, input.viewport.width)
        XCTAssertLessThanOrEqual(image.size.height, input.viewport.height)
        XCTAssertEqual(result.target.center.x, imageView.frame.midX, accuracy: 0.5)
        XCTAssertEqual(result.target.center.y, imageView.frame.midY, accuracy: 0.5)
        let coverage = try alphaCoverage(of: image)
        XCTAssertGreaterThan(coverage, 0, "The preview must contain the rendered glyphs.")
        XCTAssertLessThan(coverage, 0.75, "The preview must not include an opaque editor background.")
    }

    func testAnimationHidesOnlyRequestedGlyphsAndFinishOrStopRestoresThem() throws {
        let view = try makeTextView(text: "Selected glyphs\nUnchanged glyphs")
        let input = try textInput(in: view)
        let interaction = makeInteraction(in: input)
        let context = try requestContext(from: interaction)
        let selected = (view.text as NSString).range(of: "Selected glyphs")
        let unchanged = (view.text as NSString).range(of: "Unchanged glyphs")
        let selectedRect = try XCTUnwrap(input.writingToolsTextRects(in: selected).first)
        let unchangedRect = try XCTUnwrap(input.writingToolsTextRects(in: unchanged).first)
        let textLayer = try XCTUnwrap(descendants(of: input).compactMap { $0 as? LineFragmentView }.first?.superview)
        for fragment in textLayer.subviews { fragment.layer.displayIfNeeded() }
        let selectedInk = try alphaCoverage(of: render(textLayer, in: selectedRect))
        let unchangedInk = try alphaCoverage(of: render(textLayer, in: unchangedRect))
        XCTAssertGreaterThan(selectedInk, 0)
        XCTAssertGreaterThan(unchangedInk, 0)

        interaction.writingToolsCoordinator(interaction.coordinator, prepareFor: .anticipate, for: selected, in: context) {}

        XCTAssertEqual(try alphaCoverage(of: render(textLayer, in: selectedRect)), 0, accuracy: 0.001,
                       "Selected glyph rect: \(selectedRect); screen scale: \(view.window?.screen.scale ?? 0)")
        XCTAssertEqual(try alphaCoverage(of: render(textLayer, in: unchangedRect)), unchangedInk, accuracy: 0.001)
        interaction.writingToolsCoordinator(interaction.coordinator, finish: .anticipate, for: selected, in: context) {}
        XCTAssertEqual(try alphaCoverage(of: render(textLayer, in: selectedRect)), selectedInk, accuracy: 0.001)

        interaction.writingToolsCoordinator(interaction.coordinator, prepareFor: .remove, for: selected, in: context) {}
        view.stopWritingTools()
        XCTAssertEqual(try alphaCoverage(of: render(textLayer, in: selectedRect)), selectedInk, accuracy: 0.001)
        XCTAssertEqual(try alphaCoverage(of: render(textLayer, in: unchangedRect)), unchangedInk, accuracy: 0.001)
    }

    private func makeTextView(text: String) throws -> TextView {
        let view = TextView(frame: CGRect(x: 0, y: 0, width: 260, height: 160))
        view.contentInsetAdjustmentBehavior = .never
        view.isLineWrappingEnabled = true
        view.showLineNumbers = true
        view.textContainerInset = UIEdgeInsets(top: 11, left: 13, bottom: 7, right: 17)
        let window = UIWindow(frame: view.frame)
        let controller = UIViewController()
        window.rootViewController = controller
        controller.view.addSubview(view)
        window.isHidden = false
        self.window = window
        view.layoutIfNeeded()
        view.text = text
        let input = try textInput(in: view)
        input.layoutLines(toLocation: input.string.length)
        input.setNeedsLayout()
        input.layoutIfNeeded()
        view.setNeedsLayout()
        view.layoutIfNeeded()
        return view
    }

    private func textInput(in view: TextView) throws -> TextInputView {
        try XCTUnwrap(view.subviews.compactMap { $0 as? TextInputView }.first)
    }

    private func makeInteraction(in input: TextInputView) -> WritingToolsInteraction {
        let interaction = WritingToolsInteraction(textInputView: input)
        input.writingToolsController = interaction
        return interaction
    }

    private func requestContext(from interaction: WritingToolsInteraction) throws -> UIWritingToolsCoordinator.Context {
        var contexts: [UIWritingToolsCoordinator.Context] = []
        interaction.writingToolsCoordinator(interaction.coordinator, requestsContextsFor: .fullDocument) { contexts = $0 }
        return try XCTUnwrap(contexts.first)
    }

    private func descendants(of view: UIView) -> [UIView] {
        view.subviews.flatMap { [$0] + descendants(of: $0) }
    }

    private func render(_ view: UIView, in rect: CGRect) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = view.window?.screen.scale ?? UIScreen.main.scale
        return UIGraphicsImageRenderer(size: rect.size, format: format).image { renderer in
            renderer.cgContext.translateBy(x: -rect.minX, y: -rect.minY)
            view.layer.render(in: renderer.cgContext)
        }
    }

    private func alphaCoverage(of image: UIImage) throws -> Double {
        let image = try XCTUnwrap(image.cgImage)
        let context = try XCTUnwrap(CGContext(data: nil, width: image.width, height: image.height,
                                            bitsPerComponent: 8, bytesPerRow: image.width * 4,
                                            space: CGColorSpaceCreateDeviceRGB(),
                                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let data = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
        let pixels = image.width * image.height
        let visiblePixels = (0..<pixels).reduce(0) { $0 + (data[$1 * 4 + 3] > 0 ? 1 : 0) }
        return Double(visiblePixels) / Double(pixels)
    }
}
#endif
