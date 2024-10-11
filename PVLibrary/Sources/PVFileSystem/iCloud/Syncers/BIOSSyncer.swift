//
//  BIOSSyncer.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 10/11/24.
//

import Foundation
import SwiftCloudDrive

actor BIOSSyncer {
    
    var containerIdentifier: String { "iCloud.org.provenance-emu.provenance" }
    var storage: CloudDrive.Storage {
        return .iCloudContainer(containerIdentifier: containerIdentifier)
    }
    
    func sync() async throws{
        let customDrive = try await CloudDrive(storage: .iCloudContainer(containerIdentifier: containerIdentifier))
        let subDrive = try await CloudDrive(relativePathToRootInContainer: "BIOS")
        
        
//        let file = try await subDrive.readFile(at: "BIOS.bin")
    }
}
