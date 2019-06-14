//
//  CombineIdentifier.swift
//  OpenCombine
//
//  Created by Sergej Jaskiewicz on 10.06.2019.
//

public struct CombineIdentifier: Hashable, CustomStringConvertible {

    @usableFromInline
    internal static var _counter: UInt = 0

    @usableFromInline
    internal static var _counterLock = Lock(recursive: false)

    @usableFromInline
    internal let _id: UInt

    @inlinable
    public init() {

        var id: UInt = 0

        Self._counterLock.do {
            id = Self._counter
            Self._counter += 1
        }

        _id = id
    }

    public init(_ obj: AnyObject) {
        _id = UInt(bitPattern: ObjectIdentifier(obj))
    }

    public var description: String {
        "0x\(String(_id, radix: 16))"
    }
}
