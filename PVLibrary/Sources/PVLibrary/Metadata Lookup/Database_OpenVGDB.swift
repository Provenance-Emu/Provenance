//
//  Database_OpenVGDB.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 8/27/24.
//

public final class OpenVGDB {
    
    private let vgdb: OESQLiteDatabase
    
    public required init(database: OESQLiteDatabase? = nil) {
        if let database = database {
            if database.url.lastPathComponent != "openvgdb.sqlite" {
                fatalError("Database must be named 'openvgdb.sqlite'")
            }
            
            vgdb = database
        } else {
            let url = Bundle.module.url(forResource: "openvgdb", withExtension: "sqlite")!
            do {
                let database = try OESQLiteDatabase(withURL: url)
                self.vgdb = database
            } catch {
                fatalError("Failed to open database at \(url): \(error)")
            }
        }
    }
}

/// Artwork Queries
public extension OpenVGDB {
    
    typealias ArtworkMapping = (romMD5: [String:[String: AnyObject]], romFileNameToMD5: [String:String])
    
    
    /// Maps roms to artwork as a quick index
    /// - Returns: a tuple of Rom filename and key to md5, crc etc
    func getArtworkMappings() throws -> ArtworkMapping  {
        let results = try self.getAllReleases()
        var romMD5:[String:[String: AnyObject]] = [:]
        var romFileNameToMD5:[String:String] = [:]
        for res in results {
            if let md5 = res["romHashMD5"] as? String, !md5.isEmpty {
                let md5 : String = md5.uppercased()
                romMD5[md5] = res
                if let systemID = res["systemID"] as? Int {
                    if let filename = res["romFileName"] as? String, !filename.isEmpty {
                        let key : String = String(systemID) + ":" + filename
                        romFileNameToMD5[key]=md5
                        romFileNameToMD5[filename]=md5
                    }
                    let key : String = String(systemID) + ":" + md5
                    romFileNameToMD5[key]=md5
                }
                if let crc = res["romHashCRC"] as? String, !crc.isEmpty {
                    romFileNameToMD5[crc]=md5
                }
            }
        }
        return (romMD5, romFileNameToMD5)
    }
    
    func getAllReleases() throws -> SQLQueryResponse {
        let queryString = """
            SELECT
                release.regionLocalizedID as 'regionID',
                release.releaseCoverBack as 'boxBackURL',
                release.releaseCoverFront as 'boxImageURL',
                release.releaseDate as 'releaseDate',
                release.releaseDescription as 'gameDescription',
                release.releaseDeveloper as 'developer',
                release.releaseGenre as 'genres',
                release.releaseID as 'releaseID',
                release.releasePublisher as 'publisher',
                release.releaseReferenceURL as 'referenceURL',
                release.releaseTitleName as 'gameTitle',
                rom.TEMPRomRegion as 'region',
                rom.romFileName as 'romFileName',
                rom.romHashCRC as 'romHashCRC',
                rom.romHashMD5 as 'romHashMD5',
                rom.romID as 'romID',
                rom.romLanguage as 'language',
                rom.romSerial as 'serial',
                rom.systemID as 'systemID',
                system.systemShortName as 'systemShortName'
            FROM ROMs rom, RELEASES release, SYSTEMS system, REGIONS region
            WHERE rom.romID = release.romID
            AND rom.systemID = system.systemID
            AND release.regionLocalizedID = region.regionID
            """
        let results = try vgdb.execute(query: queryString)
        return results
    }
}
