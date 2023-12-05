import Foundation

protocol SelectedRangeWritable: SelectedRangeReadable {
    var selectedRange: NSRange { get set }
}
