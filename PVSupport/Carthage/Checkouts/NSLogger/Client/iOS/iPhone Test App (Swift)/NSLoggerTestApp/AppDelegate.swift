//
//  AppDelegate.swift
//  NSLoggerTestApp
//
//  Created by Mathieu Godart on 10/03/2017.
//  Copyright © 2017 Lauve. All rights reserved.
//

import UIKit
// Not needed as the NSLogger client source code has been
// added to this project.
//import NSLogger

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {

        // Avoid NSLogger client to search on Bonjour.
        //LoggerSetViewerHost(nil, "localhost" as NSString, 50000)

        Log(.App, .Important, "Hello, Swift Logger Tester! 🤖")

        return true
    }

}

