import Foundation

public extension Notification.Name {
    /// Posted (userInfo keys in `PVEmulatorCoreDidFailToStartUserInfoKey`) when a core's boot fails.
    static let PVEmulatorCoreDidFailToStart = Notification.Name("PVEmulatorCoreDidFailToStart")
}

public enum PVEmulatorCoreDidFailToStartUserInfoKey {
    public static let error = "error"
    public static let coreIdentifier = "coreIdentifier"
}
