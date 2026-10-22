import Foundation
import PVCoreBridge
#if canImport(PVDolphinBridge)
import PVDolphinBridge
#endif

// Core.plist names this Swift class. Forward the class capability to the bridge
// without constructing PVDolphinCore (whose initializer creates an emulator bridge).
extension PVDolphinCore: PVLibraryDiscIdentityReading {
    public static func libraryIdentity(atPath path: String) -> [String: Any]? {
        PVDolphinCoreBridge.libraryIdentity(atPath: path)
    }
}
