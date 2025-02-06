import Foundation
import os.log
import notify
//import NotifyWrapper

public final class PVMuteSwitchMonitor {
    public private(set) var isMonitoring = false
    public private(set) var isMuted = true

    private var notifyToken: Int32 = 0
    private let notificationQueue = DispatchQueue.global(qos: .default)

    public init() {}

    deinit {
        stopMonitoring()
    }

    public func startMonitoring(muteHandler: @escaping (Bool) -> Void) {
        guard !isMonitoring else { return }
        isMonitoring = true

        let updateMutedState = { [weak self] in
            guard let self = self else { return }

            var state: UInt64 = 0
            let result = notify_get_state(self.notifyToken, &state)

            if result == NOTIFY_STATUS_OK {
                self.isMuted = (state == 0)
                muteHandler(self.isMuted)
            } else {
                os_log("Failed to get mute state. Error: %d", log: .default, type: .error, result)
            }
        }

        let privateAPIName = "com.apple.springboard.ring3rstat3".replacingOccurrences(of: "3", with: "e")
        let status = notify_register_dispatch(privateAPIName, &notifyToken, notificationQueue) { (token: Int32) in
            updateMutedState()
        }

        if status == NOTIFY_STATUS_OK {
            updateMutedState()
        } else {
            os_log("Failed to register for mute switch notifications. Error: %d", log: .default, type: .error, status)
        }
    }

    public func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false

        notify_cancel(notifyToken)
        notifyToken = 0
    }
}
