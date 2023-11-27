@testable import RunestoneObservation
import XCTest

final class DictionaryObservationStoreTests: XCTestCase {
    func test_it_stores_observation() {
        let observer = MockObserver()
        let observable = MockObservable()
        let propertyChangeId = PropertyChangeId(for: observable, publishing: .didSet, of: \.str)
        let observation = Observation(
            observer: observer,
            propertyChangeId: propertyChangeId
        ) { (_: String, _: String) in }
        let sut = DictionaryObservationStore()
        XCTAssertEqual(sut.observations.count, 0)
        sut.addObservation(observation)
        XCTAssertEqual(sut.observations.count, 1)
    }

    func test_it_removes_observation() {
        let observer = MockObserver()
        let observable = MockObservable()
        let propertyChangeId = PropertyChangeId(for: observable, publishing: .didSet, of: \.str)
        let observation = Observation(
            observer: observer,
            propertyChangeId: propertyChangeId
        ) { (_: String, _: String) in }
        let sut = DictionaryObservationStore()
        sut.addObservation(observation)
        XCTAssertEqual(sut.observations.count, 1)
        sut.removeObservation(withId: observation.id)
        XCTAssertEqual(sut.observations.count, 0)
    }

    func test_it_returns_observations() {
        let observer = MockObserver()
        let observable = MockObservable()
        let propertyChangeId = PropertyChangeId(for: observable, publishing: .didSet, of: \.str)
        let observation = Observation(
            observer: observer,
            propertyChangeId: propertyChangeId
        ) { (_: String, _: String) in }
        let sut = DictionaryObservationStore()
        sut.addObservation(observation)
        XCTAssertIdentical(sut.observations.first, observation)
    }

    func test_it_returns_stored_observable() {
        let observer = MockObserver()
        let observable = MockObservable()
        let propertyChangeId = PropertyChangeId(for: observable, publishing: .didSet, of: \.str)
        let observation = Observation(
            observer: observer,
            propertyChangeId: propertyChangeId
        ) { (_: String, _: String) in }
        let sut = DictionaryObservationStore()
        sut.addObservation(observation)
        let returnedObservation = sut.observation(withId: observation.id)
        XCTAssertIdentical(returnedObservation, observation)
    }

    func test_it_removes_all_observations() {
        let observer = MockObserver()
        let observable = MockObservable()
        let propertyChangeId1 = PropertyChangeId(for: observable, publishing: .willSet, of: \.str)
        let propertyChangeId2 = PropertyChangeId(for: observable, publishing: .didSet, of: \.str)
        let observation1 = Observation(
            observer: observer,
            propertyChangeId: propertyChangeId1
        ) { (_: String, _: String) in }
        let observation2 = Observation(
            observer: observer,
            propertyChangeId: propertyChangeId2
        ) { (_: String, _: String) in }
        let sut = DictionaryObservationStore()
        sut.addObservation(observation1)
        sut.addObservation(observation2)
        XCTAssertEqual(sut.observations.count, 2)
        sut.removeAll()
        XCTAssertEqual(sut.observations.count, 0)
    }

    func test_it_returns_observations_for_property_change_id() {
        let observer = MockObserver()
        let observable = MockObservable()
        let propertyChangeId1 = PropertyChangeId(for: observable, publishing: .willSet, of: \.str)
        let propertyChangeId2 = PropertyChangeId(for: observable, publishing: .didSet, of: \.str)
        let observation1 = Observation(
            observer: observer,
            propertyChangeId: propertyChangeId1
        ) { (_: String, _: String) in }
        let observation2 = Observation(
            observer: observer,
            propertyChangeId: propertyChangeId2
        ) { (_: String, _: String) in }
        let sut = DictionaryObservationStore()
        sut.addObservation(observation1)
        sut.addObservation(observation2)
        let observations = sut.observations(for: propertyChangeId2)
        XCTAssertEqual(observations.count, 1)
        XCTAssertIdentical(observations.first, observation2)
    }
}
