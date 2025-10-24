//
//  Queue.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/29/25.
//

protocol Queue {
    associatedtype Entry
    var count: Int { get async }
    func enqueue(entry: Entry) async
    func dequeue() async -> Entry?
    func peek()  async-> Entry?
    func clear() async
    var allElements: [Entry] { get async }
    var isEmpty: Bool { get async }
}
