//
//  ReduceTests.swift
//
//
//  Created by Eric Patey on 13.09.2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class ReduceTests: XCTestCase {
    func testEmpty() {
        // Given
        let tracking = TrackingSubscriberBase<String, TestingError>(
            receiveSubscription: { $0.request(.unlimited) }
        )
        let publisher = TrackingSubject<Int>(
            receiveSubscriber: {
                XCTAssertEqual(String(describing: $0), "Reduce")
            }
        )
        // When
        publisher.reduce("", String.init).subscribe(tracking)
        // Then
        XCTAssertEqual(tracking.history, [.subscription("Reduce")])
    }

    func testBasic() {
        // Given
        let tracking = TrackingSubscriber(
            receiveSubscription: { $0.request(.unlimited) }
        )
        let publisher = TrackingSubject<Int>(
            receiveSubscriber: {
                XCTAssertEqual(String(describing: $0), "Reduce")
            }
        )
        // When
        publisher.reduce(1, { $0 * $1 }).subscribe(tracking)

        publisher.send(1)
        publisher.send(2)
        publisher.send(3)
        publisher.send(completion: .finished)
        
        // Then
        XCTAssertEqual(tracking.history, [.subscription("Reduce"),
                                          .value(6),
                                          .completion(.finished)])
    }
}
