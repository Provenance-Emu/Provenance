//
//  SharedCode.swift
//  SceneKitDemo
//
//  Created by Rob Reuss on 12/8/15.
//  Copyright © 2015 Rob Reuss. All rights reserved.
//

import Foundation
import SceneKit
//import VirtualGameController

class SharedCode: NSObject, SCNSceneRendererDelegate {
    
    var shipLeft: SCNNode!
    var shipRight: SCNNode!
    var lightNode: SCNNode!
    var cameraNode: SCNNode!
    
    var ship2IsRemote: Bool!
    
    func setup(scene: SCNScene, ship: SCNNode, lightNode: SCNNode, cameraNode: SCNNode) {
        
        self.shipLeft = ship
        self.lightNode = lightNode
        self.cameraNode = cameraNode
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.controllerDidConnect), name: NSNotification.Name(rawValue: VgcControllerDidConnectNotification), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.controllerDidDisconnect), name: NSNotification.Name(rawValue: VgcControllerDidDisconnectNotification), object: nil)
        
        if VgcManager.appRole == .MultiplayerPeer {
            
            shipRight = ship.clone()
            scene.rootNode.addChildNode(shipRight)
            self.shipRight.runAction(SCNAction.move(to: SCNVector3.init(5, 0, 0.0), duration: 0.3))
            self.shipLeft.runAction(SCNAction.move(to: SCNVector3.init(-5, 0, 0.0), duration: 0.3))

            // Keeping things simple, randomly trying to assign ships to remote/local so there is symetry between the devices
            ship2IsRemote = true
        }
        
    }
    
    func scaleShipByValue(ship: SCNNode!, scaleValue: CGFloat) {
        if let currentShip = ship {
            var scaleValue = scaleValue
            scaleValue = scaleValue + 1
            if scaleValue < 0.10 { scaleValue = 0.10 }
            currentShip.runAction(SCNAction.scale(to: scaleValue, duration: 1.0))
        }
    }
    
    /* IMPLEMENTATION USING RENDER LOOP
    func renderer(renderer: SCNSceneRenderer, willRenderScene scene: SCNScene, atTime time: NSTimeInterval) {
        
    }
    
    func renderer(renderer: SCNSceneRenderer, didApplyAnimationsAtTime time: NSTimeInterval) {
        
    }
    
    func renderer(renderer: SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: NSTimeInterval) {
        
    }
    
    func renderer(renderer: SCNSceneRenderer, didSimulatePhysicsAtTime time: NSTimeInterval) {
        
    }
    
    func renderer(renderer: SCNSceneRenderer, updateAtTime time: NSTimeInterval) {
        
        if VgcController.controllers().count > 0 {
            let controller = VgcController.controllers()[0]
            let input = controller.motion!
            
            let amplify = 2.0
            
            let x = -(input.attitude.x) * amplify
            let y = -(input.attitude.z) * amplify
            let z = -(input.attitude.y) * amplify
            
            ship.runAction(SCNAction.repeatAction(SCNAction.rotateToX(CGFloat(x), y: CGFloat(y), z: CGFloat(z), duration: 0.03), count: 1))
            ship.runAction(SCNAction.moveTo(SCNVector3.init(CGFloat( ship.position.x), CGFloat(-(input.gravity.y * 6.0)), CGFloat( ship.position.z)), duration: 1.0))
            
        }
    }
    */
    
    @objc func controllerDidConnect(notification: NSNotification) {
        
        // If we're enhancing a hardware controller, we should display the Peripheral UI
        // instead of the debug view UI
        if VgcManager.appRole == .EnhancementBridge { return }
        
        guard let newController: VgcController = notification.object as? VgcController else {
            vgcLogDebug("Got nil controller in controllerDidConnect")
            return
        }
        
        #if os(tvOS) // ATV remote will interfere so we want to exclude it's input
            if newController.isHardwareController { return }
            if newController.deviceInfo.controllerType == .MFiHardware { return }
        #endif

        /*
        VgcManager.peripheralSetup = VgcPeripheralSetup()
        
        // Turn on motion to demonstrate that
        VgcManager.peripheralSetup.motionActive = false
        VgcManager.peripheralSetup.enableMotionAttitude = true
        VgcManager.peripheralSetup.enableMotionGravity = false
        VgcManager.peripheralSetup.enableMotionUserAcceleration = false
        VgcManager.peripheralSetup.enableMotionRotationRate = false
        VgcManager.peripheralSetup.sendToController(newController)
        */
        // Dpad adjusts lighting position
        
        if var currentShip = self.shipLeft {

            #if !os(OSX)
            if newController.isLocalController {
                if UIDevice.current.userInterfaceIdiom == .pad {
                    if self.shipRight != nil { currentShip = self.shipRight }
                } else {
                    currentShip = self.shipLeft
                }
            } else {
                if UIDevice.current.userInterfaceIdiom == .pad {
                    currentShip = self.shipLeft
                } else {
                    if self.shipRight != nil { currentShip = self.shipRight }
                }
            }
            #endif
            
            #if os(iOS) || os(tvOS)
            newController.extendedGamepad?.dpad.valueChangedHandler = { (dpad, xValue, yValue) in
                
                self.lightNode.position = SCNVector3(x: Float(xValue * 10), y: Float(yValue * 20), z: Float(yValue * 30) + 10)
                
            }
            #endif
            
            #if os(OSX)
                newController.extendedGamepad?.dpad.valueChangedHandler = { (dpad, xValue, yValue) in
                    
                    self.lightNode.position = SCNVector3(x: CGFloat(xValue * 10), y: CGFloat(yValue * 20), z: CGFloat(yValue * 30) + 10)
                    
                }
            #endif
            
            
            // Left thumbstick controls move the plane left/right and up/down
            newController.extendedGamepad?.leftThumbstick.valueChangedHandler = { (dpad, xValue, yValue) in
                
                currentShip.runAction(SCNAction.move(to: SCNVector3.init(xValue * 5, yValue * 5, 0.0), duration: 0.3))
                
            }
            
            // Right thumbstick Y axis controls plane scale
            newController.extendedGamepad?.rightThumbstick.yAxis.valueChangedHandler = { (input, value) in
                
                self.scaleShipByValue(ship: currentShip, scaleValue: CGFloat((newController.extendedGamepad?.rightThumbstick.yAxis.value)!))
                
            }
            
            // Right Shoulder pushes the ship away from the user
            newController.extendedGamepad?.rightShoulder.valueChangedHandler = { (input, value, pressed) in
                
                self.scaleShipByValue(ship: currentShip, scaleValue: CGFloat((newController.extendedGamepad?.rightShoulder.value)!))
                
            }
            
            // Left Shoulder resets the reference frame
            newController.extendedGamepad?.leftShoulder.valueChangedHandler = { (input, value, pressed) in
                
                currentShip.runAction(SCNAction.repeat(SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 10.0), count: 1))
                
            }
            
            // Right trigger draws the plane toward the user
            newController.extendedGamepad?.rightTrigger.valueChangedHandler = { (input, value, pressed) in
                
                self.scaleShipByValue(ship: currentShip, scaleValue: -(CGFloat((newController.extendedGamepad?.rightTrigger.value)!)))
                
            }
            
            newController.elements.image.valueChangedHandler = { (controller, element) in
                
                //vgcLogDebug("Custom element handler fired for Send Image: \(element.value)")
                
                #if os(OSX)
                    let image = NSImage(data: (element.value as! NSData) as Data)
                #endif
                #if os(iOS) || os(tvOS)
                    let image = UIImage(data: (element.value as! NSData) as Data)
                #endif
                
                // get its material
                let material = currentShip.childNode(withName: "shipMesh", recursively: true)!.geometry?.firstMaterial!
                /*
                // highlight it
                SCNTransaction.begin()
                SCNTransaction.setAnimationDuration(0.5)
                
                // on completion - unhighlight
                SCNTransaction.setCompletionBlock {
                    SCNTransaction.begin()
                    SCNTransaction.setAnimationDuration(0.5)
                 
                    #if os(OSX)
                        material!.emission.contents = NSColor.blackColor()
                    #endif
                    #if os(iOS) || os(tvOS)
                        material!.emission.contents = UIColor.blackColor()
                    #endif
                 
                    SCNTransaction.commit()
                }
                */
                material!.diffuse.contents = image
                
                //SCNTransaction.commit()
            }
            
            
            // Position ship at a solid origin
            shipLeft.runAction(SCNAction.repeat(SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 1.3), count: 1))
            
            // Refresh on all motion changes
            newController.motion?.valueChangedHandler = { (input: VgcMotion) in
                
                let amplify = 3.14158
                //let amplify = 0.1
                
                // Invert these because we want to be able to have the ship display in a way
                // that mirrors the position of the iOS device
                let x = -(input.attitude.x) * amplify
                let y = -(input.attitude.z) * amplify
                let z = -(input.attitude.y) * amplify
                
                currentShip.runAction(SCNAction.repeat(SCNAction.rotateTo(x: CGFloat(x), y: CGFloat(y), z: CGFloat(z), duration: 0.10), count: 1))
            }
        }

        
    }
    
    @objc func controllerDidDisconnect(notification: NSNotification) {
        
        //guard let controller: VgcController = notification.object as? VgcController else { return }
        
        shipLeft.runAction(SCNAction.repeat(SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 1.0), count: 1))
        
    }
    
    
}
