import Foundation

func makeTemporaryRoot() throws -> URL {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}

/// High ports away from every app's real ones, spread so parallel test runs rarely meet.
func randomPorts() -> [Int] {
    let base = 42_000 + Int.random(in: 0..<4_000)
    return [base, base + 1, base + 2]
}

/// Collects values from callbacks that may run on any queue.
final class Recorded<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [Value] = []

    func append(_ value: Value) {
        lock.withLock { stored.append(value) }
    }

    var values: [Value] {
        lock.withLock { stored }
    }
}
