#if os(iOS)
import Combine

final class KeyWindowObserver_iOS: KeyWindowObserver {
    let isKeyWindow = CurrentValueSubject<Bool, Never>(true)
}
#endif
