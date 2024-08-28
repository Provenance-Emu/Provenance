//
//  Game.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 10/25/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

import Foundation

/// Game struct
/// Generic codable represenation of a game
public struct Game: Codable, Sendable {
    
    /// Identifiie
    public let id: String
    
    /// Game title
    public let title: String
    
    /// File object associated with Game
    public let file: FileInfo
    
    /// ID of system Game is playable on
    public let systemIdentifier: String

    /// MD5 Hash of ROM file
    public let md5: String

    /// CRC Hash of ROM file
    public let crc: String

    /// Is a favorite?
    public let isFavorite: Bool
    
    /// Number of times played
    public let playCount: UInt
    
    /// Last played date
    public let lastPlayed: Date?

    /* Extra metadata from OpenBG */
    
    /// Long test description of the game
    public let gameDescription: String?
    
    /// URL to back box art
    public let boxBackArtworkURL: String?
    
    /// Developer of the game
    public let developer: String?
    
    /// Publisher of the game
    public let publisher: String?
    
    /// Publish date of the game
    public let publishDate: String?
    
    /// Genres of the game as a comma seperated list or single entry
    public let genres: String?
    
    /// Reference URL
    public let referenceURL: String?
    
    /// Release ID
    public let releaseID: String?
    
    /// Region name
    public let regionName: String?
    
    /// Region ID
    public let regionID: Int?
    
    /// Short name of system Game is playable on
    public let systemShortName: String?
    
    /// Language of the Game
    public let language: String?
}

import CoreTransferable
import UniformTypeIdentifiers
@available(iOS 16.0, *)
extension Game: Transferable {
    public static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .rom)
    }
}
