//
//  CheatsBaseSchemas.swift
//  
//
//  Created by Joseph Mattiello on 1/11/23.
//

import Foundation
import GRDB

public enum CheatsBaseSchemas {
    public struct Cheats: Codable, FetchableRecord, PersistableRecord {
        var cheatID: Int?
        var romID: Int
        var cheatName: String
        
        var cheatActivation: String?
        var cheatDescription: String?
        var cheatSideEffect: String?
        var cheatFolderName: String?
        
        var cheatCategoryID: Int
        var cheatCode: String
        var cheatDeviceID: Int
        
        var cheatCredit: String?
        var lastModified: Date
    }
    
    public struct CheatCategories: Codable, FetchableRecord, PersistableRecord {
        var cheatCategoryID: Int?
        var cheatCategory: String
        var cheatCategoryDescription: String
        var lastModified: Date
    }
    
    public struct CheatDevices: Codable, FetchableRecord, PersistableRecord {
        var cheatDeviceID: Int?
        var systemID: Int
        
        var cheatDeviceName: String
        var cheatDeviceBrandName: String?
        var cheatDeviceFormat: String?
        var lastModified: Date
    }
}
