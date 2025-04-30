//
//  ConcurrentSet.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/29/25.
//

import Foundation
import Combine

public actor ConcurrentSet<T: Hashable>: ExpressibleByArrayLiteral,
                                         @preconcurrency
CustomStringConvertible,
ObservableObject {
    public enum ConcurrentCopyOptions {
        case removeCopiedItems
        case retainCopiedItems
    }
    // MARK: - Combine Support
    
    /// Subject for publishing set changes
    private let changeSubject = PassthroughSubject<Set<T>, Never>()
    
    /// Subject for publishing count changes
    private let countSubject = CurrentValueSubject<Int, Never>(0)
    
    /// Publisher for set changes
    public var publisher: AnyPublisher<Set<T>, Never> {
        changeSubject.eraseToAnyPublisher()
    }
    
    /// Publisher for count changes
    public var countPublisher: AnyPublisher<Int, Never> {
        countSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Properties
    private var set: Set<T>
    
    public init(arrayLiteral elements: T...) {
        set = Set(elements)
        countSubject.send(set.count)
    }
    
    public convenience init(fromSet set: Set<T>) async {
        self.init()
        await self.set.formUnion(set)
        countSubject.send(set.count)
    }
    
    public func insert(_ element: T) {
        set.insert(element)
        notifyChanges()
    }
    
    public func remove(_ element: T) -> T? {
        let removed = set.remove(element)
        notifyChanges()
        return removed
    }
    
    public func contains(_ element: T) -> Bool {
        set.contains(element)
    }
    
    public func removeAll() {
        set.removeAll()
        notifyChanges()
    }
    
    public func forEach(_ body: (T) throws -> Void) rethrows {
        try set.forEach(body)
    }
    
    public func prefix(_ maxLength: Int) -> Slice<Set<T>> {
        set.prefix(maxLength)
    }
    
    public func subtract<S>(_ other: S) where T == S.Element, S : Sequence {
        set.subtract(other)
        notifyChanges()
    }
    
    public func copy(options: ConcurrentCopyOptions) -> Set<T> {
        guard options == .removeCopiedItems
        else {
            return set
        }
        let copiedSet: Set<T> = .init(set)
        set.removeAll()
        notifyChanges()
        return copiedSet
    }
    
    public func formUnion<S>(_ other: S) where T == S.Element, S : Sequence {
        set.formUnion(other)
        notifyChanges()
    }
    
    public var isEmpty: Bool {
        return set.isEmpty
    }
    
    public var first: T? {
        return set.first
    }
    
    public var count: Int {
        return set.count
    }
    
    /// Current elements in the set as a Set
    public var elements: Set<T> {
        return set
    }
    
    /// Current elements in the set as an Array
    public var asArray: [T] {
        Array(set)
    }
    
    public func enumerated() -> EnumeratedSequence<Set<T>> {
        set.enumerated()
    }
    
    public func makeIterator() async -> Set<T>.Iterator {
        set.makeIterator()
    }
    
    public var description: String {
        return set.description
    }
    
    /// Notify subscribers of changes to the set
    private func notifyChanges() {
        let currentSet = set
        let currentCount = currentSet.count
        DispatchQueue.main.async { [weak self] in
            self?.changeSubject.send(currentSet)
            self?.countSubject.send(currentCount)
        }
    }
}
