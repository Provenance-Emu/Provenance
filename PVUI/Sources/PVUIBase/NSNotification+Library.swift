//
//  NSNotification+Library.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/10/24.
//

import Foundation

// For Obj-C
public extension NSNotification {
    @objc
    static var PVRefreshLibraryNotification: NSString {
        return "kRefreshLibraryNotification"
    }
}

public extension Notification.Name {
    static let PVResetLibrary = Notification.Name("kResetLibraryNotification")
    static let PVReimportLibrary = Notification.Name("kReimportLibraryNotification")
    static let PVRefreshLibrary = Notification.Name("kRefreshLibraryNotification")
    static let PVInterfaceDidChangeNotification = Notification.Name("kInterfaceDidChangeNotification")
}
