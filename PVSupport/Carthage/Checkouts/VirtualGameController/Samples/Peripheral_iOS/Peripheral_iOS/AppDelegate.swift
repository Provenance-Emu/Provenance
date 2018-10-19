//
//  AppDelegate.swift
//  PeripheralVirtualGameControlleriOSSample
//
//  Created by Rob Reuss on 9/13/15.
//  Copyright © 2015 Rob Reuss. All rights reserved.
//

import UIKit
import VirtualGameController

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        // This is a hack to deal with a slowly responding keyboard display
        let textField = UITextField(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
        self.window?.addSubview(textField)
        textField.becomeFirstResponder()
        textField.resignFirstResponder()
        textField.removeFromSuperview()
        
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        
        // Just as an example, sending a pause signal to our Central as we enter background
        VgcManager.elements.pauseButton.value = 1.0 as AnyObject
        VgcManager.peripheral.sendElementState(VgcManager.elements.pauseButton)
        
    }

    func applicationDidEnterBackground(_ application: UIApplication) {

    }

    func applicationWillEnterForeground(_ application: UIApplication) {

    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        
        // Letting the Central know we are back from background
        VgcManager.elements.pauseButton.value = 0.0 as AnyObject
        VgcManager.peripheral.sendElementState(VgcManager.elements.pauseButton)
        
        // Reycle service browser
        VgcManager.peripheral.stopBrowsingForServices()
        VgcManager.peripheral.browseForServices()
        
    }

    func applicationWillTerminate(_ application: UIApplication) {

        VgcManager.peripheral.disconnectFromService()
    }


}

