import Runestone
import UIKit

final class KeyboardToolsView: UIInputView {
    private let shiftLeftButton: UIButton = {
        let this = UIButton(type: .system)
        this.translatesAutoresizingMaskIntoConstraints = false
        this.setImage(UIImage(systemName: "arrow.left.to.line"), for: .normal)
        this.tintColor = .label
        return this
    }()
    private let shiftRightButton: UIButton = {
        let this = UIButton(type: .system)
        this.translatesAutoresizingMaskIntoConstraints = false
        this.setImage(UIImage(systemName: "arrow.right.to.line"), for: .normal)
        this.tintColor = .label
        return this
    }()
    private let undoButton: UIButton = {
        let this = UIButton(type: .system)
        this.translatesAutoresizingMaskIntoConstraints = false
        this.setImage(UIImage(systemName: "arrow.uturn.backward"), for: .normal)
        this.tintColor = .label
        return this
    }()
    private let redoButton: UIButton = {
        let this = UIButton(type: .system)
        this.translatesAutoresizingMaskIntoConstraints = false
        this.setImage(UIImage(systemName: "arrow.uturn.forward"), for: .normal)
        this.tintColor = .label
        return this
    }()
    private let dismissButton: UIButton = {
        let this = UIButton(type: .system)
        this.translatesAutoresizingMaskIntoConstraints = false
        this.setImage(UIImage(systemName: "keyboard.chevron.compact.down"), for: .normal)
        this.tintColor = .label
        return this
    }()

    private weak var textView: TextView?

    init(textView: TextView) {
        self.textView = textView
        let frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44)
        super.init(frame: frame, inputViewStyle: .keyboard)
        setupView()
        setupLayout()
        NotificationCenter.default.addObserver(self, selector: #selector(updateUndoRedoButtonStates), name: .NSUndoManagerCheckpoint, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateUndoRedoButtonStates), name: .NSUndoManagerDidUndoChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateUndoRedoButtonStates), name: .NSUndoManagerDidRedoChange, object: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setupView() {
        addSubview(shiftLeftButton)
        addSubview(shiftRightButton)
        addSubview(undoButton)
        addSubview(redoButton)
        addSubview(dismissButton)
        shiftLeftButton.addTarget(self, action: #selector(shiftLeft), for: .touchUpInside)
        shiftRightButton.addTarget(self, action: #selector(shiftRight), for: .touchUpInside)
        undoButton.addTarget(self, action: #selector(undo), for: .touchUpInside)
        redoButton.addTarget(self, action: #selector(redo), for: .touchUpInside)
        dismissButton.addTarget(self, action: #selector(dismissKeyboard), for: .touchUpInside)
        updateUndoRedoButtonStates()
    }

    private func setupLayout() {
        NSLayoutConstraint.activate([
            shiftLeftButton.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
            shiftLeftButton.topAnchor.constraint(equalTo: topAnchor),
            shiftLeftButton.bottomAnchor.constraint(equalTo: bottomAnchor),

            shiftRightButton.leadingAnchor.constraint(equalTo: shiftLeftButton.trailingAnchor, constant: 6),
            shiftRightButton.topAnchor.constraint(equalTo: topAnchor),
            shiftRightButton.bottomAnchor.constraint(equalTo: bottomAnchor),

            undoButton.trailingAnchor.constraint(equalTo: redoButton.leadingAnchor, constant: -10),
            undoButton.topAnchor.constraint(equalTo: topAnchor),
            undoButton.bottomAnchor.constraint(equalTo: bottomAnchor),

            redoButton.trailingAnchor.constraint(equalTo: dismissButton.leadingAnchor, constant: -30),
            redoButton.topAnchor.constraint(equalTo: topAnchor),
            redoButton.bottomAnchor.constraint(equalTo: bottomAnchor),

            dismissButton.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
            dismissButton.topAnchor.constraint(equalTo: topAnchor),
            dismissButton.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
}

private extension KeyboardToolsView {
    @objc private func shiftLeft() {
        textView?.shiftLeft()
    }

    @objc private func shiftRight() {
        textView?.shiftRight()
    }

    @objc private func undo() {
        textView?.undoManager?.undo()
    }

    @objc private func redo() {
        textView?.undoManager?.redo()
    }

    @objc private func dismissKeyboard() {
        textView?.resignFirstResponder()
    }

    @objc private func updateUndoRedoButtonStates() {
        let undoManager = textView?.undoManager
        undoButton.isEnabled = undoManager?.canUndo ?? false
        redoButton.isEnabled = undoManager?.canRedo ?? false
    }
}
