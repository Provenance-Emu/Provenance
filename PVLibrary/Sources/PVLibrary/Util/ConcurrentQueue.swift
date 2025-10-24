//
//  ConcurrentQueue.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/29/25.
//

import Foundation

public actor ConcurrentQueue<Element>: Queue, ExpressibleByArrayLiteral {
    private var collection = [Element]()
    
    public init(arrayLiteral elements: Element...) {
        collection = Array(elements)
    }
    
    public var count: Int {
        collection.count
    }
    
    public func enqueue(entry: Element) {
        collection.insert(entry, at: 0)
    }
    
    @discardableResult
    public func dequeue() -> Element? {
        guard !collection.isEmpty
        else {
            return nil
        }
        return collection.removeFirst()
    }
    
    public func peek() -> Element? {
        collection.first
    }
    
    public func clear() {
        collection.removeAll()
    }
    
    public var description: String {
        collection.description
    }
    
    public func map<T>(_ transform: (Element) throws -> T) throws -> [T] {
        try collection.map(transform)
    }
    
    public var allElements: [Element] {
        collection
    }
    
    public var isEmpty: Bool {
        collection.isEmpty
    }
}
