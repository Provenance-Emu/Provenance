//
//  SyncController.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 10/13/24.
//

import Foundation
import SwiftCloudDrive

public class SyncController: CloudDriveObserver {
    public func cloudDriveDidChange(_ drive: CloudDrive, rootRelativePaths: [RootRelativePath]) {
        // Decide if data needs refetching due to remote changes,
        // or if changes need to be applied in the UI
    }
}
