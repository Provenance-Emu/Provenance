//
//  Utils.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/10/24.
//

public extension Sequence {
    func any(_ predicate: (Self.Element) throws -> Bool) rethrows -> Bool {
        return try contains(where: { try predicate($0) == true })
    }

    func all(_ predicate: (Self.Element) throws -> Bool) rethrows -> Bool {
        let containsFailed = try contains(where: { try predicate($0) == false })
        return !containsFailed
    }

    func none(_ predicate: (Self.Element) throws -> Bool) rethrows -> Bool {
        let result = try any(predicate)
        return !result
    }

    func count(_ predicate: (Self.Element) throws -> Bool) rethrows -> Int {
        return try reduce(0, { result, element in
            result + (try predicate(element) ? 1 : 0)
        })
    }
}
