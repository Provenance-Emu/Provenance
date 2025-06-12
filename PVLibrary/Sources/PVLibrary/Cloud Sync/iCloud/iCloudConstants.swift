//
//  iCloudConstants.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/29/25.
//

import Foundation
import CloudKit

public enum iCloudConstants {
    public static let defaultProvenanceContainerIdentifier = "iCloud.org.provenance-emu.provenance"
    // Dynamic version based off of bundle Identifier
    public static let containerIdentifier =  (Bundle.main.infoDictionary?["NSUbiquitousContainers"] as? [String: AnyObject])?.keys.first ?? defaultProvenanceContainerIdentifier
    public static let container: CKContainer = CKContainer(identifier: containerIdentifier)
}
