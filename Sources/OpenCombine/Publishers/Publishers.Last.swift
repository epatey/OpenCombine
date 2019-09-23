//
//  Publishers.Last.swift
//
//  Created by Eric Patey on 13.09.2019.
//

extension Publisher {

    /// Only publishes the last element of a stream, after the stream finishes.
    /// - Returns: A publisher that only publishes the last element of a stream.
    public func last() -> Publishers.Last<Self> {
        return Publishers.Last(upstream: self)
    }
}

extension Publishers {

    /// A publisher that only publishes the last element of a stream, after the stream
    /// finishes.
    public struct Last<Upstream> : Publisher where Upstream : Publisher {

        /// The kind of values published by this publisher.
        public typealias Output = Upstream.Output

        /// The kind of errors this publisher might publish.
        ///
        /// Use `Never` if this `Publisher` does not publish errors.
        public typealias Failure = Upstream.Failure

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        public init(upstream: Upstream) {
            self.upstream = upstream
        }

        /// This function is called to attach the specified `Subscriber` to this
        /// `Publisher` by `subscribe(_:)`
        ///
        /// - SeeAlso: `subscribe(_:)`
        /// - Parameters:
        ///     - subscriber: The subscriber to attach to this `Publisher`.
        ///                   once attached it can begin to receive values.
        public func receive<Downstream>(subscriber: Downstream)
            where Downstream : Subscriber,
            Upstream.Failure == Downstream.Failure,
            Upstream.Output == Downstream.Input
        {
            let inner = Inner<Upstream, Downstream>(downstream: subscriber)
            upstream.subscribe(inner)
        }
    }
}

extension Publishers.Last {
    private final class Inner<Upstream: Publisher, Downstream: Subscriber>
        : OperatorSubscription<Downstream>,
        Subscriber,
        CustomStringConvertible,
        Subscription
        where Downstream.Input == Upstream.Output,
        Upstream.Failure == Downstream.Failure
    {
        typealias Input = Upstream.Output
        typealias Failure = Downstream.Failure

        private var value: Input?

        var description: String { return "Last" }

        func receive(subscription: Subscription) {
            upstreamSubscription = subscription
            downstream.receive(subscription: self)
            subscription.request(.unlimited)
        }

        func receive(_ input: Input) -> Subscribers.Demand {
            value = input
            return .none
        }

        func receive(completion: Subscribers.Completion<Upstream.Failure>) {
            if case .finished = completion, let value = value {
                _ = downstream.receive(value)
            }
            downstream.receive(completion: completion)
            deactivate()
        }

        func request(_ demand: Subscribers.Demand) {
        }
    }
}
