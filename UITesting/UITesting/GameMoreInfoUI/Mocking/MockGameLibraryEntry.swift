//
//  MockGameLibraryEntry.swift
//  UITesting
//
//  Created by Joseph Mattiello on 12/8/24.
//

import Combine
import Foundation

/// Mock implementation of PVGameLibraryEntry for previews
internal class MockGameLibraryEntry: ObservableObject, GameMoreInfoViewModelDataSource {
    
    var name: String? { title}
    
    var filename: String? { romPath }
    
    var system: String? { "NES" }
    
    var region: String? { "USA" }
    
    var title: String = "Super Mario World"
    var id: String = "mock-id"
    var romPath: String = "/path/to/mario.sfc"
    var customArtworkURL: String = ""
    var originalArtworkURL: URL? = URL(string: "https://example.com/mario.jpg")
    var boxFrontArtwork: URL? { URL(string: customArtworkURL) ?? originalArtworkURL }
    var requiresSync: Bool = false
    var isFavorite: Bool = true
    var romSerial: String? = "SNS-MW-USA"
    var romHeader: String? = "SUPER MARIO WORLD"
    var importDate: Date = Date()
    var systemIdentifier: String = "SNES"
    var md5Hash: String = "cdd3c8c37322978ca8669b34bc89c804"
    var crc: String = "B19ED489"
    var userPreferredCoreID: String?
    var lastPlayed: Date? = Date().addingTimeInterval(-3600) // 1 hour ago
    var playCount: Int? = 42
    var timeSpentInGame: Int? = 3600 // 1 hour
    var rating: Int = 5
    var gameDescription: String? = "Experience Mario's most exciting adventure yet in this classic SNES title!"
    var boxBackArtworkURL: URL? = URL(string: "https://example.com/mario-back.jpg")
    var developer: String? = "Nintendo"
    var publisher: String? = "Nintendo"
    var publishDate: String? = "1990-11-21"
    var genres: String? = "Platform, Action"
    var referenceURL: String? = "https://example.com/mario"
    var releaseID: String? = "SNS-MW-USA"
    var regionName: String? = "USA"
    var regionID: Int = 1
    var systemShortName: String? = "SNES"
    var language: String? = "English"
}
