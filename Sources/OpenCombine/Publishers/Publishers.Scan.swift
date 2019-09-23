//
//  Publishers.Scan.swift
//
//  Created by Eric Patey on 26.08.2019.
//

extension Publisher {

    /// Transforms elements from the upstream publisher by providing the current element
    ///  to a closure along with the last value returned by the closure.
    ///
    ///     let pub = (0...5)
    ///         .publisher
    ///         .scan(0, { return $0 + $1 })
    ///         .sink(receiveValue: { print ("\($0)", terminator: " ") })
    ///      // Prints "0 1 3 6 10 15 ".
    ///
    ///
    /// - Parameters:
    ///   - initialResult: The previous result returned by the `nextPartialResult`
    ///    closure.
    ///   - nextPartialResult: A closure that takes as its arguments the previous value
    ///   returned by the closure and the next element emitted from the upstream
    ///   publisher.
    /// - Returns: A publisher that transforms elements by applying a closure that
    ///  receives its previous return value and the next element from the upstream
    ///  publisher.
    public func scan<Result>(_ initialResult: Result,
                             _ nextPartialResult: @escaping (Result, Self.Output)
        -> Result)
        -> Publishers.Scan<Self, Result>
    {
        return Publishers.Scan(upstream: self,
                               initialResult: initialResult,
                               nextPartialResult: nextPartialResult)
    }

    /// Transforms elements from the upstream publisher by providing the current element
    ///  to an error-throwing closure along with the last value returned by the closure.
    ///
    /// If the closure throws an error, the publisher fails with the error.
    /// - Parameters:
    ///   - initialResult: The previous result returned by the `nextPartialResult`
    ///   closure.
    ///   - nextPartialResult: An error-throwing closure that takes as its arguments the
    ///    previous value returned by the closure and the next element emitted from the
    ///     upstream publisher.
    /// - Returns: A publisher that transforms elements by applying a closure that
    ///  receives its previous return value and the next element from the upstream
    ///  publisher.
    public func tryScan<Result>(_ initialResult: Result,
                                _ nextPartialResult: @escaping (Result, Self.Output)
        throws -> Result)
        -> Publishers.TryScan<Self, Result>
    {
        return Publishers.TryScan(upstream: self,
                                  initialResult: initialResult,
                                  nextPartialResult: nextPartialResult)
    }
}

extension Publishers {

    public struct Scan<Upstream, Output>: Publisher where Upstream: Publisher {

        /// The kind of errors this publisher might publish.
        ///
        /// Use `Never` if this `Publisher` does not publish errors.
        public typealias Failure = Upstream.Failure

        public let upstream: Upstream

        public let initialResult: Output

        public let nextPartialResult: (Output, Upstream.Output) -> Output

        public init(upstream: Upstream,
                    initialResult: Output,
                    nextPartialResult: @escaping (Output, Upstream.Output) -> Output) {
            self.upstream = upstream
            self.initialResult = initialResult
            self.nextPartialResult = nextPartialResult
        }

        /// This function is called to attach the specified `Subscriber` to this
        ///  `Publisher` by `subscribe(_:)`
        ///
        /// - SeeAlso: `subscribe(_:)`
        /// - Parameters:
        ///     - subscriber: The subscriber to attach to this `Publisher`.
        ///                   once attached it can begin to receive values.
        public func receive<Downstream>(subscriber: Downstream)
            where Output == Downstream.Input,
            Downstream: Subscriber,
            Upstream.Failure == Downstream.Failure
        {
            let inner = Inner<Upstream, Downstream>(downstream: subscriber,
                                                    initialResult: initialResult,
                                                    nextPartialResult: nextPartialResult)
            upstream.subscribe(inner)
        }
    }

    public struct TryScan<Upstream, Output>: Publisher where Upstream: Publisher {

        /// The kind of errors this publisher might publish.
        ///
        /// Use `Never` if this `Publisher` does not publish errors.
        public typealias Failure = Error

        public let upstream: Upstream

        public let initialResult: Output

        public let nextPartialResult: (Output, Upstream.Output) throws -> Output

        public init(
            upstream: Upstream,
            initialResult: Output,
            nextPartialResult: @escaping (Output, Upstream.Output) throws -> Output)
        {
            self.upstream = upstream
            self.initialResult = initialResult
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
            Downstream: Subscriber,
            Downstream.Failure == Publishers.TryScan<Upstream, Output>.Failure
        {
            let inner = Inner<Upstream, Downstream>(
                downstream: subscriber,
                initialResult: initialResult,
                nextPartialResult: nextPartialResult)
            upstream.subscribe(inner)
        }
    }
}

extension Publishers.Scan {
    // internal and non-final since it's subclassed by Publishers.Reduce
    internal class Inner<Upstream: Publisher, Downstream: Subscriber>
        : NonThrowingTransformingInner<Upstream, Downstream>,
        CustomStringConvertible
        where Upstream.Failure == Downstream.Failure
    {
        internal var description: String { "Scan" }

        init(downstream: Downstream,
             initialResult: Downstream.Input,
             nextPartialResult: @escaping (Downstream.Input, Upstream.Output)
            -> Downstream.Input)
        {
            var accumulator = initialResult
            super.init(downstream: downstream) {
                accumulator = nextPartialResult(accumulator, $0)
                return accumulator
            }
        }
    }
}

extension Publishers.TryScan {
    fileprivate final class Inner<Upstream: Publisher, Downstream: Subscriber>
        : ThrowingTransformingInner<Upstream, Downstream>,
        CustomStringConvertible
        where Downstream.Failure == Error
    {
        final var description: String { "TryScan" }

        init(downstream: Downstream,
             initialResult: Downstream.Input,
             nextPartialResult: @escaping (Downstream.Input, Upstream.Output) throws
            -> Downstream.Input)
        {
            var accumulator = initialResult
            super.init(downstream: downstream) {
                accumulator = try nextPartialResult(accumulator, $0)
                return accumulator
            }
        }
    }
}