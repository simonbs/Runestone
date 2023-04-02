#if os(iOS)
import Foundation

final class LineControllerStorageLowMemoryHandler: LowMemoryHandling {
    private let lineControllerStorage: LineControllerStorage
    private let lineFragmentLayouter: LineFragmentLayouter

    init(lineControllerStorage: LineControllerStorage, lineFragmentLayouter: LineFragmentLayouter) {
        self.lineControllerStorage = lineControllerStorage
        self.lineFragmentLayouter = lineFragmentLayouter
    }

    func handleLowMemory() {
        let visibleLineIDs = lineFragmentLayouter.visibleLineIDs
        lineControllerStorage.removeAllLineControllers(exceptLinesWithID: visibleLineIDs)
    }
}
#endif
