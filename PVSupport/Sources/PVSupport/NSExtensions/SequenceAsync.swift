//
//  SequenceAsync.swift
//  PVSupport
//
//  Created by Joseph Mattiello on 8/30/24.
//

public
extension Sequence {
    func asyncMap<T>(
        _ transform: (Self.Element) async throws -> T
    ) async rethrows -> [T] {
        var values = [T]()

        for element in self {
            try await values.append(transform(element))
        }

        return values
    }
}

public
extension Sequence {
    func asyncCompactMap<T>(
        _ transform: (Self.Element) async throws -> T?
    ) async rethrows -> [T] {
        var values = [T]()

        for element in self {
            let value = try await transform(element)
            switch value {
            case .none:
                continue
            case .some(let value):
                values.append(value)
            }
        }
        return values
    }
}

public
extension Sequence {
    func asyncFilter(
        _ isIncluded: (Self.Element) async throws -> Bool
    ) async rethrows -> [Self.Element] {
        var values = [Self.Element]()

        for element in self {
            if try await isIncluded(element) {
                try values.append(element)
            }
        }

        return values
    }
}

public
extension Sequence where Self.Element: Sendable {
    func concurrentMap<T: Sendable>(
        _ transform: @escaping @Sendable (Self.Element) async throws -> T
    ) async throws -> [T] {
        let tasks = map { element in
            Task {
                try await transform(element)
            }
        }

        return try await tasks.asyncMap { task in
            try await task.value
        }
    }
}

public
extension Sequence {
    func asyncForEach(
        _ operation: (Self.Element) async throws -> Void
    ) async rethrows {
        for element in self {
            try await operation(element)
        }
    }
}

public extension Sequence where Self.Element: Sendable {
    func concurrentForEach(
        _ operation: @escaping @Sendable (Self.Element) async -> Void
    ) async {
        await withTaskGroup(of: Void.self) { group in
            for element in self {
                group.addTask {
                    await operation(element)
                }
            }
        }
    }
}

//public
//extension Collection {
//    @discardableResult
//    func concurrentCompactMap<T>(
//        maxInParallel: Int = Int.max,
//        _ transform: @escaping (Element) async throws -> T?
//    ) async rethrows -> [T] {
//        try await concurrentMap(
//            maxInParallel: maxInParallel,
//            transform
//        ).compactMap()
//    }
//}

//public
//extension Sequence {
//    func concurrentForEach(
//        maxInParallel: Int = Int.max,
//        _ body: @escaping (Self.Element) async throws -> Void
//    ) async rethrows {
//        try await withThrowingTaskGroup(of: Void.self) { group in
//            var offset = 0
//            var iterator = makeIterator()
//            while offset < maxInParallel, let element = iterator.next() {
//                group.addTask { try await body(element) }
//                offset += 1
//            }
//
//            while try await group.next() != nil {
//                if let element = iterator.next() {
//                    group.addTask { try await body(element) }
//                }
//            }
//        }
//    }
//}
