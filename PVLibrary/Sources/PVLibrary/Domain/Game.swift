//
//  Game.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 10/25/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

import Foundation

public struct Game: Codable {
    public let id: String
    public let title: String
    public let file: FileInfo
    public let systemIdentifier: String

    public let md5: String
    public let crc: String

    public let isFavorite: Bool
    public let playCount: UInt
    public let lastPlayed: Date?

    /* Extra metadata from OpenBG */
    public let gameDescription: String?
    public let boxBackArtworkURL: String?
    public let developer: String?
    public let publisher: String?
    public let publishDate: String?
    public let genres: String? // Is a comma seperated list or single entry
    public let referenceURL: String?
    public let releaseID: String?
    public let regionName: String?
    public let regionID: Int?
    public let systemShortName: String?
    public let language: String?
}
