import SwiftUI
import UIKit

struct SwiftUIMenuButton: UIViewRepresentable {
    let selectionHandler: MenuSelectionHandler

    func makeUIView(context: Context) -> some UIView {
        MenuButton.makeConfigured(with: selectionHandler)
    }

    func updateUIView(_ uiView: UIViewType, context: Context) {}
}
