import Foundation

protocol MarkedRangeWritable: MarkedRangeReadable {
    var markedRange: NSRange? { get set }
}
