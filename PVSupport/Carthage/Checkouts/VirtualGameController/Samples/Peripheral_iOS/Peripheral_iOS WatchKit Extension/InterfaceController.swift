//
//  InterfaceController.swift
//  vgcBridge WatchKit Extension
//
//  Created by Rob Reuss on 9/29/15.
//  Copyright © 2015 Rob Reuss. All rights reserved.
//

import WatchKit
import Foundation
import WatchConnectivity
import VirtualGameController

class InterfaceController: WKInterfaceController {
    
    @IBOutlet var elementsTable: WKInterfaceTable!
    
    @objc let watchConnectivity: VgcWatchConnectivity!
    @objc var session : WCSession!
    
    override init() {
        
        VgcManager.startAs(.Peripheral, appIdentifier: "", customElements: CustomElements(), customMappings: CustomMappings())
        
        vgcLogDebug("Successfully ran startAs")
        
        watchConnectivity = VgcWatchConnectivity()
        
        watchConnectivity.valueChangedHandler = { (element: Element) in
            
            vgcLogDebug("Watch handler fired for \(element.name) with value \(element.value)")
            
        }
        
    }
    
    // Watch-based motion functionality is not performant, probably not enough
    // for a game. Not sure if the issue is the performance of the accelerometer or
    // watch connectivity.  Needs investigation.  Tested using an HTTP server on the
    // iPhone but didn't get any better performance, suggesting it is an accelerometer
    // issue.
    @IBAction func motionSwitch(_ value: Bool) {
        if value == true {
            watchConnectivity.motion.start()
        } else {
            watchConnectivity.motion.stop()
        }
    }
    
    // Just as a simple example, display a table of the watch profile elements.
    @objc func updateElementsTable() {

        vgcLogDebug("Number of element rows: \(watchConnectivity.elements.allElementsCollection().count)")
        self.elementsTable.setNumberOfRows(watchConnectivity.elements.allElementsCollection().count, withRowType: "elementsTableRow")
        var index = 0
        for element in watchConnectivity.elements.watchProfileElements {
            
            vgcLogDebug("Working on row for \(element.name)")
            
            if let row = elementsTable.rowController(at: index) as? ElementsTableRow {
                print("Labeling row")
                row.elementLabel.setText(element.name)
            }
            
            index += 1
        }
    }
    
    override func table(_ table: WKInterfaceTable, didSelectRowAt rowIndex: Int) {
        
        // Perform a wrist tap with each button push, just to be cute.
        WKInterfaceDevice.current().play(WKHapticType.click)
        
        // Toggle element.  This implementation could be enhanced by using touches
        // on the component used in the table row (such as a button) so that there
        // are seperate sendElementValueToBridge calls for touch down and up.
        let element = watchConnectivity.elements.watchProfileElements[rowIndex]
        element.value = 1.0 as AnyObject
        watchConnectivity.sendElementState(element: element)
        element.value = 0.0 as AnyObject
        watchConnectivity.sendElementState(element: element)
        
    }
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        self.updateElementsTable()
        
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }
    
    
}
