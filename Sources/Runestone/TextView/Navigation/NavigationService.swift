import LineManager
import StringView

final class NavigationService {
    private let stringView: StringView
    private let lineManager: LineManager
    private let lineControllerStorage: LineControllerStorage
    private var stringTokenizer: StringTokenizer {
        StringTokenizer(stringView: stringView, lineManager: lineManager, lineControllerStorage: lineControllerStorage)
    }
    private var characterNavigationLocationService: CharacterNavigationLocationFactory {
        CharacterNavigationLocationFactory(stringView: stringView)
    }
    private var wordNavigationLocationService: WordNavigationLocationFactory {
        WordNavigationLocationFactory(stringTokenizer: stringTokenizer)
    }
    #if os(macOS)
    private let lineNavigationLocationService: StatefulLineNavigationLocationFactory
    #else
    private let lineNavigationLocationService: LineNavigationLocationFactory
    #endif

    init(stringView: StringView, lineManager: LineManager, lineControllerStorage: LineControllerStorage) {
        self.stringView = stringView
        self.lineManager = lineManager
        self.lineControllerStorage = lineControllerStorage
        #if os(macOS)
        self.lineNavigationLocationService = StatefulLineNavigationLocationFactory(
            lineManager: lineManager,
            lineControllerStorage: lineControllerStorage
        )
        #else
        self.lineNavigationLocationService = LineNavigationLocationFactory(
            lineManager: lineManager,
            lineControllerStorage: lineControllerStorage
        )
        #endif
    }

    func location(movingFrom location: Int, byCharacterCount offset: Int, inDirection direction: TextDirection) -> Int {
        characterNavigationLocationService.location(movingFrom: location, byCharacterCount: offset, inDirection: direction)
    }

    func location(movingFrom location: Int, byLineCount offset: Int, inDirection direction: TextDirection) -> Int {
        lineNavigationLocationService.location(movingFrom: location, byLineCount: offset, inDirection: direction)
    }

    func location(movingFrom sourceLocation: Int, byWordCount offset: Int, inDirection direction: TextDirection) -> Int {
        wordNavigationLocationService.location(movingFrom: sourceLocation, byWordCount: offset, inDirection: direction)
    }

    func location(moving sourceLocation: Int, toBoundary boundary: TextBoundary, inDirection direction: TextDirection) -> Int {
        stringTokenizer.location(from: sourceLocation, toBoundary: boundary, inDirection: direction) ?? sourceLocation
    }

    func resetPreviousLineNavigationOperation() {
        #if os(macOS)
        lineNavigationLocationService.reset()
        #endif
    }
}
