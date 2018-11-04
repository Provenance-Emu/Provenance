//
//  AppDelegate.swift
//  emulator-osx
//
//  Created by admin on 6/1/15.
//  Copyright (c) 2015 reicast. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!


    func applicationDidFinishLaunching(_ aNotification: Notification) {
        emu_main();
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        emu_dc_stop()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

