//
//  Publishers.Reduce.swift
//
//  Created by Eric Patey on 13.09.2019.
//

extension Publisher {

    /// Applies a closure that accumulates each element of a stream and publishes a final
    /// result upon completion.
    ///
    /// - Parameters:
    ///   - initialResult: The value the closure receives the first time it is called.
    ///   - nextPartialResult: A closure that takes the previously-accumulated value and
    ///   the next element from the upstream publisher to produce a new value.
    /// - Returns: A publisher that applies the closure to all received elements and
    /// produces an accumulated value when the upstream publisher finishes.
    public func reduce<Result>(_ initialResult: Result,
                               _ nextPartialResult: @escaping (Result, Self.Output)
        -> Result)
        -> Publishers.Reduce<Self, Result>
    {
        return Publishers.Reduce(upstream: self,
                                 initial: initialResult,
                                 nextPartialResult: nextPartialResult)
    }

    /// Applies an error-throwing closure that accumulates each element of a stream and
    /// publishes a final result upon completion.
    ///
    /// If the closure throws an error, the publisher fails, passing the error to its
    /// subscriber.
    /// - Parameters:
    ///   - initialResult: The value the closure receives the first time it is called.
    ///   - nextPartialResult: An error-throwing closure that takes the previously
    ///   accumulated value and the next element from the upstream publisher to produce a
    ///   new value.
    /// - Returns: A publisher that applies the closure to all received elements and
    /// produces an accumulated value when the upstream publisher finishes.
    public func tryReduce<Result>(_ initialResult: Result,
                                  _ nextPartialResult: @escaping (Result, Self.Output)
        throws -> Result)
        -> Publishers.TryReduce<Self, Result>
    {
        return Publishers.TryReduce(upstream: self,
                                    initial: initialResult,
                                    nextPartialResult: nextPartialResult)
    }
}

extension Publishers {

    /// A publisher that applies a closure to all received elements and produces an
    /// accumulated value when the upstream publisher finishes.
    public struct Reduce<Upstream, Output> : Publisher where Upstream : Publisher {

        /// The kind of errors this publisher might publish.
        ///
        /// Use `Never` if this `Publisher` does not publish errors.
        public typealias Failure = Upstream.Failure

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        /// The initial value provided on the first invocation of the closure.
        public let initial: Output

        /// A closure that takes the previously-accumulated value and the next element
        /// from the upstream publisher to produce a new value.
        public let nextPartialResult: (Output, Upstream.Output) -> Output

        public init(upstream: Upstream,
                    initial: Output,
                    nextPartialResult: @escaping (Output, Upstream.Output) -> Output) {
            self.upstream = upstream
            self.initial = initial
            self.nextPartialResult = nextPartialResult
        }

        /// This function is called to attach the specified `Subscriber` to this
        /// `Publisher` by `subscribe(_:)`
        ///
        /// - SeeAlso: `subscribe(_:)`
        /// - Parameters:
        ///     - subscriber: The subscriber to attach to this `Publisher`.
        ///                   once attached it can begin to receive values.
        public func receive<Downstream>(subscriber: Downstream)
            where Output == Downstream.Input,
            Downstream : Subscriber,
            Upstream.Failure == Downstream.Failure
        {
            let inner = Inner<Upstream, Downstream>(downstream: subscriber)
            let composed = CustomSubscriberName(upstream: upstream, subscriberName: "Reduce")
                .scan(initial, nextPartialResult)
                .last()
            composed.subscribe(inner)
        }
    }

    /// A publisher that applies an error-throwing closure to all received elements and
    /// produces an accumulated value when the upstream publisher finishes.
    public struct TryReduce<Upstream, Output> : Publisher where Upstream : Publisher {

        /// The kind of errors this publisher might publish.
        ///
        /// Use `Never` if this `Publisher` does not publish errors.
        public typealias Failure = Error

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        /// The initial value provided on the first invocation of the closure.
        public let initial: Output

        /// An error-throwing closure that takes the previously-accumulated value and the
        /// next element from the upstream to produce a new value.
        ///
        /// If this closure throws an error, the publisher fails and passes the error to
        /// its subscriber.
        public let nextPartialResult: (Output, Upstream.Output) throws -> Output

        public init(upstream: Upstream,
                    initial: Output,
                    nextPartialResult: @escaping (Output, Upstream.Output)
            throws -> Output)
        {
            self.upstream = upstream
            self.initial = initial
            self.nextPartialResult = nextPartialResult
        }

        /// This function is called to attach the specified `Subscriber` to this
        /// `Publisher` by `subscribe(_:)`
        ///
        /// - SeeAlso: `subscribe(_:)`
        /// - Parameters:
        ///     - subscriber: The subscriber to attach to this `Publisher`.
        ///                   once attached it can begin to receive values.
        public func receive<Downstream>(subscriber: Downstream)
            where Output == Downstream.Input,
            Downstream : Subscriber,
            Downstream.Failure == Publishers.TryReduce<Upstream, Output>.Failure
        {

        }
    }
}

// public for now just so that I can test
public struct CustomSubscriberName<Upstream> : Publisher where Upstream : Publisher {
    public typealias Output = Upstream.Output
    public typealias Failure = Upstream.Failure
    private let subscriberName: String
    public let upstream: Upstream

    public init(upstream: Upstream, subscriberName: String) {
        self.upstream = upstream
        self.subscriberName = subscriberName
    }

    public func receive<Downstream>(subscriber: Downstream)
        where Output == Downstream.Input,
        Downstream : Subscriber,
        Upstream.Failure == Downstream.Failure
    {
        let inner = Inner<Upstream, Downstream>(downstream: subscriber,
                                                name: subscriberName)
        upstream.subscribe(inner)
    }
}

extension CustomSubscriberName {
    fileprivate class Inner<Upstream: Publisher, Downstream: Subscriber>
        : OperatorSubscription<Downstream>,
        Subscriber,
        CustomStringConvertible
        where Upstream.Failure == Downstream.Failure,
        Upstream.Output == Downstream.Input
    {
        func receive(subscription: Subscription) {
            upstreamSubscription = subscription
            downstream.receive(subscription: subscription)
        }

        func receive(_ input: Upstream.Output) -> Subscribers.Demand {
            return downstream?.receive(input) ?? .none
        }

        func receive(completion: Subscribers.Completion<Upstream.Failure>) {
            downstream?.receive(completion: completion)
        }

        typealias Input = Upstream.Output
        typealias Failure = Upstream.Failure

        final let description: String

        init(downstream: Downstream, name: String) {
            self.description = name
            super.init(downstream: downstream)
        }
    }
}

extension Publishers.Reduce {
    fileprivate final class Inner<Upstream: Publisher, Downstream: Subscriber> :
        OperatorSubscription<Downstream>,
        Subscriber,
        Subscription,
        CustomStringConvertible
    {
        typealias Input = Downstream.Input
        typealias Failure = Downstream.Failure

        func receive(subscription: Subscription) {
            upstreamSubscription = subscription
            downstream.receive(subscription: self)
        }

        func receive(_ input: Downstream.Input) -> Subscribers.Demand {
            return downstream.receive(input)
        }

        func receive(completion: Subscribers.Completion<Downstream.Failure>) {
            downstream.receive(completion: completion)
            deactivate()
        }

        func request(_ demand: Subscribers.Demand) {
            upstreamSubscription?.request(demand)
        }

        final var description: String { "Reduce" }

    }
}
