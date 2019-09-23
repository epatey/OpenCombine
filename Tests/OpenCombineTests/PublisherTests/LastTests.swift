//
//  LastTests.swift
//
//
//  Created by Eric Patey on 14.09.2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class LastTests: XCTestCase {
    func testUpstreamNotCancelledWhenFinished() {
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)

        let last = publisher.last()

        let tracking = TrackingSubscriber()

        last.subscribe(tracking)

        publisher.send(completion: .finished)

        XCTAssertEqual(subscription.history, [.requested(.unlimited)])
    }

    func testUpstreamNotCancelledWhenFailed() {
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)

        let last = publisher.last()

        let tracking = TrackingSubscriber()

        last.subscribe(tracking)

        publisher.send(completion: .failure(.oops))

        XCTAssertEqual(subscription.history, [.requested(.unlimited)])
    }

    func testLifecycle() throws {

        var deinitCounter = 0

        let onDeinit = { deinitCounter += 1 }

        do {
            let passthrough = PassthroughSubject<Int, TestingError>()
            let last = passthrough.last()
            let emptySubscriber = TrackingSubscriber(onDeinit: onDeinit)
            XCTAssertTrue(emptySubscriber.history.isEmpty)
            last.subscribe(emptySubscriber)
            XCTAssertEqual(emptySubscriber.subscriptions.count, 1)
            passthrough.send(31)
            XCTAssertEqual(emptySubscriber.inputs.count, 0)
            passthrough.send(completion: .failure("failure"))
            XCTAssertEqual(emptySubscriber.completions.count, 1)
        }

        XCTAssertEqual(deinitCounter, 1)

        do {
            let passthrough = PassthroughSubject<Int, TestingError>()
            let last = passthrough.last()
            let emptySubscriber = TrackingSubscriber(onDeinit: onDeinit)
            XCTAssertTrue(emptySubscriber.history.isEmpty)
            last.subscribe(emptySubscriber)
            XCTAssertEqual(emptySubscriber.subscriptions.count, 1)
            XCTAssertEqual(emptySubscriber.inputs.count, 0)
            XCTAssertEqual(emptySubscriber.completions.count, 0)
        }

        XCTAssertEqual(deinitCounter, 1)

        var subscription: Subscription?

        do {
            let passthrough = PassthroughSubject<Int, TestingError>()
            let last = passthrough.last()
            let emptySubscriber = TrackingSubscriber(
                receiveSubscription: { subscription = $0; $0.request(.unlimited) },
                onDeinit: onDeinit
            )
            XCTAssertTrue(emptySubscriber.history.isEmpty)
            last.subscribe(emptySubscriber)
            XCTAssertEqual(emptySubscriber.subscriptions.count, 1)
            passthrough.send(31)
            XCTAssertEqual(emptySubscriber.inputs.count, 0)
            XCTAssertEqual(emptySubscriber.completions.count, 0)
            XCTAssertNotNil(subscription)
        }

        XCTAssertEqual(deinitCounter, 1)
        try XCTUnwrap(subscription).cancel()
        XCTAssertEqual(deinitCounter, 2)
    }

    class FooSubscriber: Subscriber {
        typealias Input = Int
        typealias Failure = TestingError
        public var subscription: Subscription?

        deinit {
            Swift.print("FooSubscriber deinit")
        }

        func receive(subscription: Subscription) {
            self.subscription = subscription
        }

        func receive(_ input: Int) -> Subscribers.Demand {
            return .none
        }

        func receive(completion: Subscribers.Completion<TestingError>) {

        }

    }

    enum Eric: CaseIterable {
        case subscriptionCancelled
        case upstreamFinished
        case upStreamFailed
    }

        func testReleasesSubscriberAfterCancel() {
            for operation in Eric.allCases {
                weak var weakSubscriber: FooSubscriber?
                var subscription: Subscription?
                let upstream = PassthroughSubject<Int, TestingError>()

                do {
                    let subscriber = FooSubscriber()
                    upstream.subscribe(subscriber)
                    subscription = subscriber.subscription
                    weakSubscriber = subscriber
                }

                upstream.send(1)

                switch operation {
                case .subscriptionCancelled:
                    subscription?.cancel()
                case .upstreamFinished:
                    upstream.send(completion: .finished)
                case .upStreamFailed:
                    upstream.send(completion: .failure(.oops))
                }
                if weakSubscriber != nil { XCTFail("Subscriber still alive")}
            }
        }
/*
    func testReleasesSubscriberAfterFinish() {
        weak var weakSubscriber: FooSubscriber?
        var subscription: Subscription?

        do {
            let upstream = PassthroughSubject<Int, TestingError>()
            let subscriber = FooSubscriber()

            upstream.subscribe(subscriber)
            subscription = subscriber.getAndClearSubscription()
            weakSubscriber = subscriber

            upstream.send(1)

            upstream.send(completion: .finished)
        }
//        subscription?.cancel()
//        weakSubscriber?.subscription = nil
        if weakSubscriber != nil { XCTFail("Subscriber still alive")}
    }
 */

/*
    func testItGoesAway() {
        weak var weakUpstream: PassthroughSubject<Int, TestingError>?
        weak var weakSubscriber: FooSubscriber?

        do {
            let upstream = PassthroughSubject<Int, TestingError>()
            let last = upstream.last()

            let subscriber = FooSubscriber()

            last.subscribe(subscriber)

            upstream.send(1)
            upstream.send(2)
            upstream.send(3)
            //                publisher.send(completion: .finished)

            weakUpstream = upstream
            weakSubscriber = subscriber
        }
        weakSubscriber?.subscription?.cancel()
        weakSubscriber?.subscription = nil
        if weakUpstream != nil { XCTFail("Upstream still alive")}
        if weakSubscriber != nil { XCTFail("Subscriber still alive")}
    }
*/

    func testBasic() {
        let publisher = PassthroughSubject<Int, Error>()
        let last = publisher.last()

        let tracking = TrackingSubscriberBase<Int, Error>()

        last.subscribe(tracking)
        publisher.send(1)
        publisher.send(2)
        publisher.send(3)
        publisher.send(completion: .finished)

        XCTAssertEqual(tracking.history,
                       [.subscription("Last"),
                        .value(3),
                        .completion(.finished)])
    }

    func testNoValues() {
        let publisher = PassthroughSubject<Int, Error>()
        let last = publisher.last()

        let tracking = TrackingSubscriberBase<Int, Error>()

        last.subscribe(tracking)
        publisher.send(completion: .finished)

        XCTAssertEqual(tracking.history,
                       [.subscription("Last"),
                        .completion(.finished)])
    }
}
