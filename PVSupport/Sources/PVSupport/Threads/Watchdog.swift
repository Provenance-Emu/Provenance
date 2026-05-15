import Foundation
#if canImport(os)
import os
#endif

#if !os(Linux)
/// Class for logging excessive blocking on the main thread.
final public class Watchdog {
    fileprivate let pingThread: PingThread

    @objc public static let defaultThreshold = 0.4

    /// Convenience initializer that allows you to construct a `WatchDog` object with default behavior.
    /// - parameter threshold: number of seconds that must pass to consider the main thread blocked.
    /// - parameter strictMode: boolean value that stops the execution whenever the threshold is reached.
    @objc public convenience init(threshold: Double = Watchdog.defaultThreshold, strictMode: Bool = false) {
        let message = "👮 Main thread was blocked for " + String(format: "%.2f", threshold) + "s 👮"

        self.init(threshold: threshold) {
            if strictMode {
                fatalError(message)
            } else {
                NSLog("%@", message)
            }
        }
    }

    /// Default initializer that allows you to construct a `WatchDog` object specifying a custom callback.
    /// - parameter threshold: number of seconds that must pass to consider the main thread blocked.
    /// - parameter watchdogFiredCallback: a callback that will be called when the the threshold is reached
    @objc public init(threshold: Double = Watchdog.defaultThreshold, watchdogFiredCallback: @escaping () -> Void) {
        self.pingThread = PingThread(threshold: threshold, handler: watchdogFiredCallback)

        self.pingThread.start()
    }

    deinit {
        pingThread.cancel()
    }
}

private final class PingThread: Thread {
    fileprivate var pingTaskIsRunning: Bool {
        get { pingTaskIsRunningLock.withLock { $0 } }
        set { pingTaskIsRunningLock.withLock { $0 = newValue } }
    }
    private let pingTaskIsRunningLock = OSAllocatedUnfairLock<Bool>(initialState: false)
    fileprivate var semaphore = DispatchSemaphore(value: 0)
    fileprivate let threshold: Double
    fileprivate let handler: () -> Void

    init(threshold: Double, handler: @escaping () -> Void) {
        self.threshold = threshold
        self.handler = handler
        super.init()
        self.name = "WatchDog"
    }

    @preconcurrency
    nonisolated
    override func main() {
        let lock = pingTaskIsRunningLock
        let sem = semaphore
        while !isCancelled {
            pingTaskIsRunning = true
            DispatchQueue.main.async {
                lock.withLock { $0 = false }
                sem.signal()
            }

            Thread.sleep(forTimeInterval: threshold)
            if pingTaskIsRunning {
                handler()
            }

            _ = sem.wait(timeout: DispatchTime.distantFuture)
        }
    }
}
#endif
