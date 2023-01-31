import Foundation

extension TextViewController {
    func moveLeft() {
        move(by: .character, offset: -1)
    }

    func moveRight() {
        move(by: .character, offset: 1)
    }

    func moveUp() {
        move(by: .line, offset: -1)
    }

    func moveDown() {
        move(by: .line, offset: 1)
    }
}

private extension TextViewController {
    private func move(by granularity: NavigationService.Granularity, offset: Int) {
        guard let sourceLocation = selectedRange?.location else {
            return
        }
        let destinationLocation = navigationService.location(movingFrom: sourceLocation, by: granularity, offset: offset)
        selectedRange = NSRange(location: destinationLocation, length: 0)
    }
}
