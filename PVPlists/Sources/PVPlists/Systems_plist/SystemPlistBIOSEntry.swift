//
//  SystemPlistBIOSEntry.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 8/6/24.
//

public struct SystemPlistBIOSEntry: Codable, Equatable, Hashable {
    public private(set) var Description: String
    public private(set) var MD5: String
    public private(set) var Name: String
    public private(set) var Size: Int
    public private(set) var Optional: Bool?
}
