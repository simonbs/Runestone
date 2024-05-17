//import _RunestoneMultiPlatform
//import Combine
//import CoreGraphics
//import CoreText
//import Foundation
//#if os(iOS)
//import UIKit
//#endif
//
//struct MarkedRangeLineFragmentRenderer: LineFragmentRendering {
//    let markedRange: CurrentValueSubject<NSRange?, Never>
//    let inlinePredictionRange: CurrentValueSubject<NSRange?, Never>
//    let backgroundColor: CurrentValueSubject<MultiPlatformColor, Never>
//    let backgroundCornerRadius: CurrentValueSubject<CGFloat, Never>
//
//    func render<LineType: Line>(
//        _ lineFragment: LineType.LineFragmentType,
//        in line: LineType,
//        to context: CGContext
//    ) {
//        guard let markedRange = markedRange.value, inlinePredictionRange.value == nil else {
//            return
//        }
//        context.saveGState()
//        let startX = CTLineGetOffsetForStringIndex(lineFragment.line, markedRange.lowerBound, nil)
//        let endX = CTLineGetOffsetForStringIndex(lineFragment.line, markedRange.upperBound, nil)
//        let rect = CGRect(x: startX, y: 0, width: endX - startX, height: lineFragment.scaledSize.height)
//        context.setFillColor(backgroundColor.value.cgColor)
//        if backgroundCornerRadius.value > 0 {
//            let cornerRadius = backgroundCornerRadius.value
//            let path = CGPath(
//                roundedRect: rect,
//                cornerWidth: cornerRadius,
//                cornerHeight: cornerRadius,
//                transform: nil
//            )
//            context.addPath(path)
//            context.fillPath()
//        } else {
//            context.fill(rect)
//        }
//        context.restoreGState()
//    }
//}
