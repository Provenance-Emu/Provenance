import Foundation
import PVCoreBridge
import PVEmulatorCore
import PVLogging

@objc @objcMembers
public final class PVAzaharCore: PVEmulatorCore, @unchecked Sendable {
    let _bridge: PVAzaharCoreBridge = .init()
    public required init() {
        super.init()
        self.bridge = (_bridge as! any ObjCBridgedCoreBridge)
    }
}
