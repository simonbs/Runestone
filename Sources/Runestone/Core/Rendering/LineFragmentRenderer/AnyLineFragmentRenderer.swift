import CoreGraphics

struct AnyLineFragmentRenderer<LineType: Line>: LineFragmentRendering {
    private let _render: (LineType.LineFragmentType, LineType, CGContext) -> Void
    private let _equals: (AnyLineFragmentRenderer<LineType>) -> Bool

    init<T: LineFragmentRendering>(_ lineFragmentRenderer: T) {
        _render = { _lineFragment, _line, context in
            guard let line = _line as? T.LineType else {
                fatalError("Unexpected type of line. Expected \(T.LineType.self) but got type \(type(of: _line))")
            }
            guard let lineFragment = _lineFragment as? T.LineType.LineFragmentType else {
                fatalError(
                    "Unexpected type of line fragment."
                    + " Expected \(T.LineType.LineFragmentType.self) but got type \(type(of: _lineFragment))"
                )
            }
            lineFragmentRenderer.render(lineFragment, in: line, to: context)
        }
        _equals = { other in
            guard let otherLineFragmentRenderer = other as? T else {
                return false
            }
            return lineFragmentRenderer == otherLineFragmentRenderer
        }
    }

    func render(
        _ lineFragment: LineType.LineFragmentType,
        in line: LineType,
        to context: CGContext
    ) {
        _render(lineFragment, line, context)
    }

    static func ==(lhs: AnyLineFragmentRenderer<LineType>, rhs: AnyLineFragmentRenderer<LineType>) -> Bool {
        lhs._equals(rhs)
    }
}
