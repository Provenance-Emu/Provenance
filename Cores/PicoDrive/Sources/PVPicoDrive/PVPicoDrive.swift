//
//  PVPicoDrive.swift
//
//
//  Created by Joseph Mattiello on 5/27/24.
//

import Foundation
import PVEmulatorCore
import PVCoreBridge
import PVCoreObjCBridge
import PVPicoDriveBridge
import PVLogging
#if canImport(GameController)
import GameController
#endif

public class PVPicoDrive: PVEmulatorCore, @unchecked Sendable {

    let _bridge: PVPicoDriveBridge = .init()

    required init() {
        super.init()
        self.bridge = (_bridge as! any ObjCBridgedCoreBridge)
    }

    public override func initialize() {
        super.initialize()
        self.copyCartHWCFG()
    }
 
}

extension PVPicoDrive {
    func copyCartHWCFG() {
        let bundle = Bundle.module
        guard let cartPath = bundle.path(forResource: "carthw", ofType: "cfg") else {
            ELOG("Error: Unable to find carthw.cfg in the bundle")
            return
        }
        
        guard let systemPath = self.BIOSPath else {
            ELOG("Error: Unable to find BIOSPath")
            return
        }
        let destinationPath = systemPath.appending("/carthw.cfg") //.appendingPathComponent("carthw.cfg")
        let fileManager = FileManager.default
        
        if !fileManager.fileExists(atPath: destinationPath) {
            do {
                try fileManager.copyItem(atPath: cartPath, toPath: destinationPath)
                print("Copied default carthw.cfg file into system directory. \(self.BIOSPath)")
            } catch {
                print("Error copying carthw.cfg:\n \(error.localizedDescription)\nsource: \(cartPath)\ndestination: \(destinationPath)")
            }
        }
    }
}

extension PVPicoDrive: PVSega32XSystemResponderClient {
    public func didPush(_ button: PVCoreBridge.PVSega32XButton, forPlayer player: Int) {
        (_bridge as! PVSega32XSystemResponderClient).didPush(button, forPlayer: player)
    }
    
    public func didRelease(_ button: PVCoreBridge.PVSega32XButton, forPlayer player: Int) {
        (_bridge as! PVSega32XSystemResponderClient).didRelease(button, forPlayer: player)
    }
}
