//
// Copyright © 2017 Gavrilov Daniil
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

import QuartzCore

import UIKit

/// Memory usage tuple. Contains used and total memory in bytes.
public typealias MemoryUsage = (used: UInt64, total: UInt64)

/// Performance report tuple. Contains CPU usage in percentages, FPS and memory usage.
public typealias PerformanceReport = (cpuUsage: Double, fps: Int, memoryUsage: MemoryUsage)

/// Performance monitor delegate. Gets called on the main thread.
public protocol PerformanceMonitorDelegate: AnyObject {
    /// Reports monitoring information to the receiver.
    ///
    /// - Parameters:
    ///   - performanceReport: Performance report tuple. Contains CPU usage in percentages, FPS and memory usage.
    func performanceMonitor(didReport performanceReport: PerformanceReport)
}

public protocol PerformanceViewConfigurator {
    var options: PerformanceMonitor.DisplayOptions { get set }
    var userInfo: PerformanceMonitor.UserInfo { get set }
    var style: PerformanceMonitor.Style { get set }
    var interactors: [UIGestureRecognizer]? { get set }
}

public protocol StatusBarConfigurator {
    var statusBarHidden: Bool { get set }
    var statusBarStyle: UIStatusBarStyle { get set }
}

// MARK: Class Definition

/// Performance calculator. Uses CADisplayLink to count FPS. Also counts CPU and memory usage.
internal class PerformanceCalculator {

    // MARK: Structs

    private struct Constants {
        static let accumulationTimeInSeconds = 1.0
    }

    // MARK: Internal Properties

    internal var onReport: ((_ performanceReport: PerformanceReport) -> Void)?

    // MARK: Private Properties

    private var displayLink: CADisplayLink!
    private let linkedFramesList = LinkedFramesList()
    private var startTimestamp: TimeInterval?
    private var accumulatedInformationIsEnough = false

    // MARK: Init Methods & Superclass Overriders

    required internal init() {
        self.configureDisplayLink()
    }
}

// MARK: Public Methods

internal extension PerformanceCalculator {
    /// Starts performance monitoring.
    func start() {
        self.startTimestamp = Date().timeIntervalSince1970
        self.displayLink?.isPaused = false
    }

    /// Pauses performance monitoring.
    func pause() {
        self.displayLink?.isPaused = true
        self.startTimestamp = nil
        self.accumulatedInformationIsEnough = false
    }
}

// MARK: Timer Actions

private extension PerformanceCalculator {
    @objc func displayLinkAction(displayLink: CADisplayLink) {
        self.linkedFramesList.append(frameWithTimestamp: displayLink.timestamp)
        self.takePerformanceEvidence()
    }
}

// MARK: Monitoring

private extension PerformanceCalculator {
    func takePerformanceEvidence() {
        if self.accumulatedInformationIsEnough {
            let cpuUsage = self.cpuUsage()
            let fps = self.linkedFramesList.count
            let memoryUsage = self.memoryUsage()
            self.report(cpuUsage: cpuUsage, fps: fps, memoryUsage: memoryUsage)
        } else if let start = self.startTimestamp, Date().timeIntervalSince1970 - start >= Constants.accumulationTimeInSeconds {
            self.accumulatedInformationIsEnough = true
        }
    }

    func cpuUsage() -> Double {
        var totalUsageOfCPU: Double = 0.0
        var threadsList: thread_act_array_t?
        var threadsCount = mach_msg_type_number_t(0)
        let threadsResult = withUnsafeMutablePointer(to: &threadsList) {
            return $0.withMemoryRebound(to: thread_act_array_t?.self, capacity: 1) {
                task_threads(mach_task_self_, $0, &threadsCount)
            }
        }

        if threadsResult == KERN_SUCCESS, let threadsList = threadsList {
            for index in 0..<threadsCount {
                var threadInfo = thread_basic_info()
                var threadInfoCount = mach_msg_type_number_t(THREAD_INFO_MAX)
                let infoResult = withUnsafeMutablePointer(to: &threadInfo) {
                    $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                        thread_info(threadsList[Int(index)], thread_flavor_t(THREAD_BASIC_INFO), $0, &threadInfoCount)
                    }
                }

                guard infoResult == KERN_SUCCESS else {
                    break
                }

                let threadBasicInfo = threadInfo as thread_basic_info
                if threadBasicInfo.flags & TH_FLAGS_IDLE == 0 {
                    totalUsageOfCPU = (totalUsageOfCPU + (Double(threadBasicInfo.cpu_usage) / Double(TH_USAGE_SCALE) * 100.0))
                }
            }
        }

        vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: threadsList)), vm_size_t(Int(threadsCount) * MemoryLayout<thread_t>.stride))
        return totalUsageOfCPU
    }

    func memoryUsage() -> MemoryUsage {
        var taskInfo = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info>.size) / 4
        let result: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }

        var used: UInt64 = 0
        if result == KERN_SUCCESS {
            used = UInt64(taskInfo.phys_footprint)
        }

        let total = ProcessInfo.processInfo.physicalMemory
        return (used, total)
    }
}

// MARK: Configurations

private extension PerformanceCalculator {
    func configureDisplayLink() {
        self.displayLink = CADisplayLink(target: self, selector: #selector(PerformanceCalculator.displayLinkAction(displayLink:)))
        self.displayLink.isPaused = true
        self.displayLink?.add(to: .current, forMode: .common)
    }
}

// MARK: Support Methods

private extension PerformanceCalculator {
    func report(cpuUsage: Double, fps: Int, memoryUsage: MemoryUsage) {
        let performanceReport = (cpuUsage: cpuUsage, fps: fps, memoryUsage: memoryUsage)
        self.onReport?(performanceReport)
    }
}

public final class PerformanceMonitor {

    // MARK: Enums

    public enum Style {
        case dark
        case light
        case custom(backgroundColor: UIColor, borderColor: UIColor, borderWidth: CGFloat, cornerRadius: CGFloat, textColor: UIColor, font: UIFont)
    }

    public enum UserInfo {
        case none
        case custom(string: String)
    }

    private enum States {
        case started
        case paused
        case pausedBySystem
    }

    // MARK: Structs

    public struct DisplayOptions: OptionSet {
        public let rawValue: Int

        /// CPU usage and FPS.
        public static let performance = DisplayOptions(rawValue: 1 << 0)

        /// Memory usage.
        public static let memory = DisplayOptions(rawValue: 1 << 1)

        /// Application version with build number.
        public static let application = DisplayOptions(rawValue: 1 << 2)

        /// Device model.
        public static let device = DisplayOptions(rawValue: 1 << 3)

        /// System name with version.
        public static let system = DisplayOptions(rawValue: 1 << 4)

        /// Default dispaly options - CPU usage and FPS, application version with build number and system name with version.
        public static let `default`: DisplayOptions = [.performance, .application, .system]

        /// All dispaly options.
        public static let all: DisplayOptions = [.performance, .memory, .application, .device, .system]

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
    }

    // MARK: Public Properties

    public weak var delegate: PerformanceMonitorDelegate?

//    public var performanceViewConfigurator: PerformanceViewConfigurator {
//        get {
//            return self.performanceView
//        }
//        set { }
//    }

//    public var statusBarConfigurator: StatusBarConfigurator {
//        get {
//            guard let rootViewController = self.performanceView.rootViewController as? WindowViewController else {
//                fatalError("Root view controller must be a kind of WindowViewController.")
//            }
//            return rootViewController
//        }
//        set { }
//    }

    // MARK: Private Properties

    private static var sharedPerformanceMonitor: PerformanceMonitor!

//    private let performanceView = PerformanceView()
    private let performanceCalculator = PerformanceCalculator()
    private var state = States.paused

    // MARK: Init Methods & Superclass Overriders

    /// Initializes performance monitor with parameters.
    ///
    /// - Parameters:
    ///   - options: Display options. Allows to change the format of the displayed information.
    ///   - style: Style. Allows to change the appearance of the displayed information.
    ///   - delegate: Performance monitor output.
    required public init(options: DisplayOptions = .default, style: Style = .dark, delegate: PerformanceMonitorDelegate? = nil) {
//        self.performanceView.options = options
//        self.performanceView.style = style

        self.performanceCalculator.onReport = { [weak self] (performanceReport) in
            DispatchQueue.main.async {
                self?.apply(performanceReport: performanceReport)
            }
        }

        self.delegate = delegate
        self.subscribeToNotifications()
    }

    /// Initializes performance monitor singleton with default properties.
    ///
    /// - Returns: Performance monitor singleton.
    public class func shared() -> PerformanceMonitor {
        if self.sharedPerformanceMonitor == nil {
            self.sharedPerformanceMonitor = PerformanceMonitor()
        }
        return self.sharedPerformanceMonitor
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: Public Methods
public extension PerformanceMonitor {
//    func hide() {
//        self.performanceView.hide()
//    }
//
//    func show() {
//        self.performanceView.show()
//    }

    func start() {
        switch self.state {
        case .started:
            return
        case .paused, .pausedBySystem:
            self.state = .started
            self.performanceCalculator.start()
        }
    }

    func pause() {
        switch self.state {
        case .paused:
            return
        case .started, .pausedBySystem:
            self.state = .paused
            self.performanceCalculator.pause()
        }
    }
}

// MARK: Notifications & Observers
private extension PerformanceMonitor {
    func applicationWillEnterForegroundNotification(notification: Notification) {
        switch self.state {
        case .started, .paused:
            return
        case .pausedBySystem:
            self.state = .started
            self.performanceCalculator.start()
        }
    }

    func applicationDidEnterBackgroundNotification(notification: Notification) {
        switch self.state {
        case .paused, .pausedBySystem:
            return
        case .started:
            self.state = .pausedBySystem
            self.performanceCalculator.pause()
        }
    }
}

// MARK: Configurations
private extension PerformanceMonitor {
    func subscribeToNotifications() {
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] (notification) in
            self?.applicationWillEnterForegroundNotification(notification: notification)
        }

        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] (notification) in
            self?.applicationDidEnterBackgroundNotification(notification: notification)
        }
    }
}

// MARK: Support Methods
private extension PerformanceMonitor {
    func apply(performanceReport: PerformanceReport) {
//        self.performanceView.update(withPerformanceReport: performanceReport)
        self.delegate?.performanceMonitor(didReport: performanceReport)
    }
}

// MARK: Class Definition
/// Linked list node. Represents frame timestamp.
internal class FrameNode {

    // MARK: Public Properties

    var next: FrameNode?
    weak var previous: FrameNode?

    private(set) var timestamp: TimeInterval

    /// Initializes linked list node with parameters.
    ///
    /// - Parameter timeInterval: Frame timestamp.
    public init(timestamp: TimeInterval) {
        self.timestamp = timestamp
    }
}

// MARK: Class Definition
/// Linked list. Each node represents frame timestamp.
/// The only function is append, which will add a new frame and remove all frames older than a second from the last timestamp.
/// As a result, the number of items in the list will represent the number of frames for the last second.
internal class LinkedFramesList {

    // MARK: Private Properties

    private var head: FrameNode?
    private var tail: FrameNode?

    // MARK: Public Properties

    private(set) var count = 0
}

// MARK: Public Methods
internal extension LinkedFramesList {
    /// Appends new frame with parameters.
    ///
    /// - Parameter timestamp: New frame timestamp.
    func append(frameWithTimestamp timestamp: TimeInterval) {
        let newNode = FrameNode(timestamp: timestamp)
        if let lastNode = self.tail {
            newNode.previous = lastNode
            lastNode.next = newNode
            self.tail = newNode
        } else {
            self.head = newNode
            self.tail = newNode
        }

        self.count += 1
        self.removeFrameNodes(olderThanTimestampMoreThanSecond: timestamp)
    }
}

// MARK: Support Methods
private extension LinkedFramesList {
    func removeFrameNodes(olderThanTimestampMoreThanSecond timestamp: TimeInterval) {
        while let firstNode = self.head {
            guard timestamp - firstNode.timestamp > 1.0 else {
                break
            }

            let nextNode = firstNode.next
            nextNode?.previous = nil
            firstNode.next = nil
            self.head = nextNode

            self.count -= 1
        }
    }
}
