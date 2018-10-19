//
//  GameViewController.swift
//  SpriteKitExample
//
//  Created by Rob Reuss on 10/7/17.
//  Copyright © 2017 Rob Reuss. All rights reserved.
//

import UIKit
import SpriteKit
import GameplayKit
import ARKit
import VirtualGameController

class GameViewController: UIViewController, ARSKViewDelegate {
    
    var scene: GameScene!
    var sceneView: ARSKView!
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        if let view = self.view as! SKView? {
            // Load the SKScene from 'GameScene.sks'
            
            self.sceneView = ARSKView(frame: CGRect(origin: CGPoint(x: 0,y: 0), size: view.bounds.size))
            view.addSubview(self.sceneView)
            
            // Set the view's delegate
            sceneView.delegate = self
            
            // Show statistics such as fps and node count
            sceneView.showsFPS = true
            sceneView.showsNodeCount = true
            
            // Load the SKScene from 'Scene.sks'
            scene = GameScene(fileNamed: "GameScene")
            scene.scaleMode = .aspectFill
            sceneView.presentScene(scene)
            
            view.ignoresSiblingOrder = true
            
            view.showsFPS = true
            view.showsNodeCount = true
            
            NotificationCenter.default.addObserver(self, selector: #selector(self.controllerDidConnect), name: NSNotification.Name(rawValue: VgcControllerDidConnectNotification), object: nil)
            //NotificationCenter.default.addObserver(self, selector: #selector(self.localControllerDidConnect(_:)),name: NSNotification.Name(rawValue: VgcControllerDidConnectNotification), object: nil)
            
            NotificationCenter.default.addObserver(self, selector: #selector(self.foundService(_:)), name: NSNotification.Name(rawValue: VgcPeripheralFoundService), object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(self.peripheralDidConnect(_:)), name: NSNotification.Name(rawValue: VgcPeripheralDidConnectNotification), object: nil)
            
            VgcManager.startAs(.MultiplayerPeer, appIdentifier: "vgc", customElements: nil, customMappings: nil, includesPeerToPeer: false, enableLocalController: true)
            
            // Look for Centrals.  Note, system is automatically setup to use UID-based device names so that a
            // Peripheral device does not try to connect to it's own Central service.
            VgcManager.peripheral.browseForServices()
            
            VgcManager.loggerLogLevel = .Debug
            
        }
    }
    
    
    @objc func controllerDidConnect(notification: NSNotification) {
        
        guard let newController: VgcController = notification.object as? VgcController else {
            vgcLogDebug("Got nil controller in controllerDidConnect")
            return
        }
        
        // Left thumbstick controls move the plane left/right and up/down
        newController.extendedGamepad?.leftThumbstick.valueChangedHandler = { (dpad, xValue, yValue) in
            
            print("X value thumbstick: \(xValue)")
            let myPos = CGPoint(x: Double(xValue), y: Double(yValue))
            self.scene.addSpinnyNode(pos: myPos)
            
        }
        
        
        // Refresh on all motion changes
        newController.motion?.valueChangedHandler = { (input: VgcMotion) in
            
            let myPos = CGPoint(x: CGFloat(input.attitude.x * 1000), y: CGFloat(input.attitude.y * 1000))
            self.scene.addSpinnyNode(pos: myPos)
        
        }
        
    }
    
    
    // Auto-connect to opposite device
    @objc func foundService(_ notification: Notification) {
        print("Connecting to service")
        let vgcService = notification.object as! VgcService
        VgcManager.peripheral.connectToService(vgcService)
    }
    
    @objc func peripheralDidConnect(_ notification: Notification) {
        
        vgcLogDebug("Got VgcPeripheralDidConnectNotification notification")
        VgcManager.peripheral.stopBrowsingForServices()
        
        VgcManager.peripheral.motion.enableAttitude = true
        VgcManager.peripheral.motion.enableGravity = false
        VgcManager.peripheral.motion.enableRotationRate = false
        VgcManager.peripheral.motion.enableUserAcceleration = false
        
        VgcManager.peripheral.motion.enableAdaptiveFilter = true
        VgcManager.peripheral.motion.enableLowPassFilter = true
        
        VgcManager.peripheral.motion.start()
        
    }
    
    
    override var shouldAutorotate: Bool {
        return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return .allButUpsideDown
        } else {
            return .all
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
}


