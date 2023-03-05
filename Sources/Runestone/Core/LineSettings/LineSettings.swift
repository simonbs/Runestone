import Combine
import CoreGraphics

struct TypesetSettings {
    let isLineWrappingEnabled = CurrentValueSubject<Bool, Never>(false)
    let lineHeightMultiplier = CurrentValueSubject<CGFloat, Never>(1)
    let lineBreakMode = CurrentValueSubject<LineBreakMode, Never>(.byWordWrapping)
    let kern = CurrentValueSubject<CGFloat, Never>(0)
    let tabWidth = CurrentValueSubject<CGFloat, Never>(10)
}
