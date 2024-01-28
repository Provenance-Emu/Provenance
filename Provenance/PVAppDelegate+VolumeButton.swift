//
//  PVAppDelegate+VolumeButton.swift
//  Provenance
//
//  Created by Joseph Mattiello on 7/6/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

/*
 Allow overriding the Volume buttons to do other actions
 using private apis.
 https://jjrscott.com/override-ios-volume-buttons/
 */

import PVLogging
import Foundation
import UIKit

#if canImport(CarPlay)
import CarPlay

/*
 https://developer.apple.com/documentation/carplay/cpinstrumentclustersetting
 
 https://developer.apple.com/documentation/carplay/cpinstrumentclustercontroller
 
 https://developer.apple.com/documentation/carplay/cpinstrumentclustercontrollerdelegate
 
 https://developer.apple.com/documentation/carplay/cptemplateapplicationinstrumentclusterscene
 class CPTemplateApplicationInstrumentClusterScene : UIScene

 */

// class CarPlayHacks {
//    func createWindow() -> CRCarPlayWindow {
//        liveCarplayWindow = [[CRCarPlayWindow alloc] initWithBundleIdentifier:identifier];
// Receive notifications for Carplay connect/disconnect events. When a Carplay screen becomes unavailable while an app is being hosted on it, that app window needs to be closed
// [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(carplayIsConnectedChanged) name:@"CarPlayIsConnectedDidChange" object:nil];
//

//    }
// func createCarPlayApp() {
//    // Create a fake declaration so this app appears to support carplay.
//      id carplayDeclaration = [[objc_getClass("CRCarPlayAppDeclaration") alloc] init];
//      // This is not template-driven -- important. Without specifying this, the process that hosts the Templates will continuously spin up
//      // and crash, trying to find a non-existant template for this declaration
//      objcInvoke_1(carplayDeclaration, @"setSupportsTemplates:", 0);
//      objcInvoke_1(carplayDeclaration, @"setSupportsMaps:", 1);
//      objcInvoke_1(carplayDeclaration, @"setBundleIdentifier:", appBundleID);
//      objcInvoke_1(carplayDeclaration, @"setBundlePath:", objcInvoke(appInfo, @"bundleURL"));
//      setIvar(appInfo, @"_carPlayDeclaration", carplayDeclaration);
//
//      // Add a tag to the app, to keep track of which apps have been "forced" into carplay
//      NSArray *newTags = @[@"CarPlayEnable"];
//      if (objcInvoke(appInfo, @"tags"))
//      {
//          newTags = [newTags arrayByAddingObjectsFromArray:objcInvoke(appInfo, @"tags")];
//      }
//      setIvar(appInfo, @"_tags", newTags);
// }
// id allAppsConfiguration = [[objc_getClass("FBSApplicationLibraryConfiguration") alloc] init];
//   objcInvoke_1(allAppsConfiguration, @"setApplicationInfoClass:", objc_getClass("CARApplicationInfo"));
//   objcInvoke_1(allAppsConfiguration, @"setApplicationPlaceholderClass:", objc_getClass("FBSApplicationPlaceholder"));
//   objcInvoke_1(allAppsConfiguration, @"setAllowConcurrentLoading:", 1);
// id allAppsLibrary = objcInvoke_1([objc_getClass("FBSApplicationLibrary") alloc], @"initWithConfiguration:", allAppsConfiguration);
//
//        // Notify SpringBoard of the launch. SpringBoard will host the application + UI
// [[objc_getClass("NSDistributedNotificationCenter") defaultCenter] postNotificationName:@"com.carplayenable" object:nil userInfo:@{@"identifier": objcInvoke(arg1, @"bundleIdentifier")}];
// https://github.com/EthanArbuckle/carplay-cast/tree/master/src
//
// }

// https://developer.apple.com/documentation/carplay/cpwindow class CPWindow : UIWindow

/* info.plist https://developer.apple.com/documentation/carplay/cptemplateapplicationscenedelegate
 <key>CPTemplateApplicationSceneSessionRoleApplication</key>
 <array>
     <dict>
         <key>UISceneClassName</key>
         <string>CPTemplateApplicationScene</string>
         <key>UISceneConfigurationName</key>
         <string>MyCarPlaySceneConfiguration</string>
         <!-- Specify the name of your scene delegate class. -->
         <key>UISceneDelegateClassName</key>
         <string>MyCarPlaySceneDelegate</string>
     </dict>
 </array>
 */

// https://developer.apple.com/documentation/carplay/cptemplateapplicationscenedelegate
// CPTemplateApplicationSceneDelegate
//
// extension PVAppDelegate {
//    optional func application(
//        _ application: UIApplication,
//        configurationForConnecting connectingSceneSession: UISceneSession,
//        options: UIScene.ConnectionOptions
//    ) -> UISceneConfiguration {
//
//    }
//
// }

// extension TemplateManager: CPMapTemplateDelegate {
//
//    func mapTemplate(_ mapTemplate: CPMapTemplate, panWith direction: CPMapTemplate.PanDirection) {
//        mainMapViewController.panInDirection(direction)
//    }
//
//    func mapTemplate(_ mapTemplate: CPMapTemplate, selectedPreviewFor trip: CPTrip, using routeChoice: CPRouteChoice) {
//        mainMapViewController.setPolylineVisible(true)
//    }
//
//    func mapTemplate(_ mapTemplate: CPMapTemplate, startedTrip trip: CPTrip, using routeChoice: CPRouteChoice) {
//
//        MemoryLogger.shared.appendEvent("Beginning navigation guidance.")
//
//        let navSession = mapTemplate.simulateCoastalRoadsNavigation(
//            trip: trip,
//            routeChoice: routeChoice,
//            traitCollection: mainMapViewController.traitCollection)
//        navigationSession = navSession
//
//        simulateNavigation(for: navSession, maneuvers: mapTemplate.coastalRoadsManeuvers(compatibleWith: mainMapViewController.traitCollection))
//    }

extension PVAppDelegate: CPTemplateApplicationSceneDelegate {
//    func templateApplicationScene(
//        _ templateApplicationScene: CPTemplateApplicationScene,
//        didConnect interfaceController: CPInterfaceController
//    ) { }

//    func application(
    //        _ application: UIApplication,
    //        configurationForConnecting connectingSceneSession: UISceneSession,
    //        options: UIScene.ConnectionOptions
    //    ) -> UISceneConfiguration {
    //
    //    }

//    func interfaceController(_ interfaceController: CPInterfaceController, didConnectWith window: CPWindow, style: UIUserInterfaceStyle) {
//        MemoryLogger.shared.appendEvent("Connected to CarPlay window.")
//
//        carplayInterfaceController = interfaceController
//        carplayInterfaceController!.delegate = self
//
//        window.rootViewController = mainMapViewController
//        carWindow = window
//
//        let mapTemplate = CPMapTemplate.coastalRoadsMapTemplate(compatibleWith: mainMapViewController.traitCollection, zoomInAction: {
//            MemoryLogger.shared.appendEvent("Map zoom in.")
//            self.mainMapViewController.zoomIn()
//        }, zoomOutAction: {
//            MemoryLogger.shared.appendEvent("Map zoom out.")
//            self.mainMapViewController.zoomOut()
//        })
//
//        mapTemplate.mapDelegate = self
//
//        baseMapTemplate = mapTemplate
//
//        installBarButtons()
//
//        interfaceController.setRootTemplate(mapTemplate, animated: true) { (success, _) in
//            if success {
//                MemoryLogger.shared.appendEvent("Root MapTemplate set successfully")
//            }
//        }
//    }
}
#endif

@objc public protocol UIApplicationPrivate {
    @objc func setWantsVolumeButtonEvents(_:Bool)
}

class VolumeButtonsObserver {
    private static var observer: NSObjectProtocol?

    static func setup(with application: UIApplication) {
        observer = NotificationCenter.default.addObserver(forName: nil,
                                                          object: nil,
                                                          queue: nil,
                                                          using: handleEvent)

        let application = unsafeBitCast(application, to:UIApplicationPrivate.self)
        application.setWantsVolumeButtonEvents(true)
    }

    private static func handleEvent(_ notification: Notification) {
        switch notification.name.rawValue {
        case "_UIApplicationVolumeUpButtonDownNotification": DLOG("Volume Up Button Down")
        case "_UIApplicationVolumeUpButtonUpNotification": DLOG("Volume Up Button Up")
        case "_UIApplicationVolumeDownButtonDownNotification": DLOG("Volume Down Button Down")
        case "_UIApplicationVolumeDownButtonUpNotification": DLOG("Volume Down Button Up")
        default: break
        }
    }
}
