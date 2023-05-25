import Combine

protocol KeyWindowObserver {
    var isKeyWindow: CurrentValueSubject<Bool, Never> { get }
}
