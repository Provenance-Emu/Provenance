//
//  OpenVGDBSchemas.swift
//  
//
//  Created by Joseph Mattiello on 1/11/23.
//

import Foundation
import GRDB

public enum OpenVGDBSchemas {
    public struct Regions: Codable, FetchableRecord, PersistableRecord {
        var regionID: Int?
        var regionName: String
        var lastModified: Date
    }

    public struct Releases: Codable, FetchableRecord, PersistableRecord {
        var releaseID: Int?
        var romID: Int
        var releaseTitleName: String
        var regionLocalizedID: Int
        
        var releaseCoverFront: String?
        var releaseCoverBack: String?
        var releaseCoverCart: String?
        var releaseCoverDisc: String?
        var releaseDescription: String?
        var releaseDeveloper: String?
        var releasePublisher: String?
        var releaseGenre: String?
        var releaseDate: String?
        var releaseReferenceURL: String?
        var releaseReferenceImageURL: String?
        var lastModified: Date
    }
    
    public struct Roms: Codable, FetchableRecord, PersistableRecord {
        var romID: Int?
        var systemID: Int
        var regionID: Int

        var romHashCRC: String?
        var romHashMD5: String?
        var romHashSHA1: String?

        var romSize: Int?
        
        var romFileName: String
        var romExtensionlessFileName: String
        
        var romParent: String?
        var romSerial: String?
        var romHeader: String?
        var romLanguage: String?

        var romDumpSource: String

        var lastModified: Date
    }
    
    public struct Systems: Codable, FetchableRecord, PersistableRecord {
        var systemID: Int?

        var systemName: String
        var systemShortName: String

        var systemHeaderSizeBytes: Int?
        var systemHashless: Int?
        var systemHeader: Int?

        var systemSerial: String?
        var systemOEID: String?

        var lastModified: Date
    }
}
