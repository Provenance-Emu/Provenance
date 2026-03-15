//
//  SystemPlistBIOSEntry.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 8/6/24.
//

public struct SystemPlistBIOSEntry: Codable, Equatable, Hashable {
    public private(set) var Description: String
    /// MD5 is optional to support alias entries that match by filename only.
    /// Alias entries (e.g. tos102.img as an alternate name for tos.img) omit MD5 so
    /// the BIOS importer does not match them by hash — avoiding duplicate file creation
    /// when the same ROM is imported under a canonical name that already has an MD5 entry.
    public private(set) var MD5: String?
    public private(set) var Name: String
    public private(set) var Size: Int
    public private(set) var Optional: Bool?
}
