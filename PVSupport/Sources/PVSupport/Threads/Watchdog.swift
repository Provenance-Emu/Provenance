import Foundation

/// Class for logging excessive blocking on the main thread.
final public class Watchdog: NSObject {
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
        super.init()
    }
    
    deinit {
        pingThread.cancel()
    }
}

private final class PingThread: Thread {
    fileprivate var pingTaskIsRunning: Bool {
        get {
            objc_sync_enter(pingTaskIsRunningLock)
            let result = _pingTaskIsRunning;
            objc_sync_exit(pingTaskIsRunningLock)
            return result
        }
        set {
            objc_sync_enter(pingTaskIsRunningLock)
            _pingTaskIsRunning = newValue
            objc_sync_exit(pingTaskIsRunningLock)
        }
    }
    private var _pingTaskIsRunning = false
    private let pingTaskIsRunningLock = NSObject()
    fileprivate var semaphore = DispatchSemaphore(value: 0)
    fileprivate let threshold: Double
    fileprivate let handler: () -> Void
    
    init(threshold: Double, handler: @escaping () -> Void) {
        self.threshold = threshold
        self.handler = handler
        super.init()
        self.name = "WatchDog"
    }
    
    override func main() {
        while !isCancelled {
            pingTaskIsRunning = true
            DispatchQueue.main.async {
                self.pingTaskIsRunning = false
                self.semaphore.signal()
            }
            
            Thread.sleep(forTimeInterval: threshold)
            if pingTaskIsRunning {
                handler()
            }
            
            _ = semaphore.wait(timeout: DispatchTime.distantFuture)
        }
    }
}
