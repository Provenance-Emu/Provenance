//
//  MockGameLibraryEntry.swift
//  UITesting
//
//  Created by Joseph Mattiello on 12/8/24.
//

import Combine
import Foundation
import UIKit
import PVRealm

public protocol GameMoreInfoViewModelDataSource: ObservableObject {
    var name: String? { get set }
    var filename: String? { get }
    var system: String? { get }
    var region: String? { get set }
    var developer: String? { get set }
    var publishDate: String? { get set }
    var genres: String? { get set }
    var playCount: Int? { get }
    var timeSpentInGame: Int? { get }
    var boxFrontArtwork: UIImage? { get }
    var boxBackArtwork: UIImage? { get }
    var referenceURL: URL? { get }
    var id: String { get }
    var boxArtAspectRatio: CGFloat { get }
    var debugDescription: String? { get }
    /// Game description text if available
    var gameDescription: String? { get }
}

/// Mock implementation of PVGameLibraryEntry for previews
internal class MockGameLibraryEntry: Identifiable, ObservableObject, GameMoreInfoViewModelDataSource {
    var name: String? {
        get { title }
        set { title = newValue ?? "" }
    }

    var filename: String? { romPath }

    var system: String? { "NES" }

    var region: String? {
        get { regionName }
        set { regionName = newValue }
    }

    var title: String = "Super Mario World"
    var id: String = "mock-id"
    var romPath: String = "/path/to/mario.sfc"
    var customArtworkURL: String = ""
    private var originalArtworkURL: URL? = URL(string: "https://example.com/mario.jpg")
    var boxFrontArtwork: UIImage? {
        UIImage.image(withText: title, ratio: boxArtAspectRatio)
    }
    var boxBackArtwork: UIImage? {
        UIImage.image(withText: title, ratio: boxArtAspectRatio)
    }
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
    var gameDescription: String? = """
        Experience Mario's most exciting adventure yet in this classic SNES title!
        Join Mario and Yoshi as they explore Dinosaur Land to rescue Princess Peach
        from the evil Bowser. Discover new power-ups, secret exits, and hidden paths
        across multiple worlds filled with challenging enemies and puzzles.
        """
    private var boxBackArtworkURL: URL? = URL(string: "https://example.com/mario-back.jpg")
    var developer: String? = "Nintendo"
    var publisher: String? = "Nintendo"
    var publishDate: String? = "1990-11-21"
    var genres: String? = "Platform, Action"
    var referenceURL: URL? = URL(string:"https://example.com/mario")
    var releaseID: String? = "SNS-MW-USA"
    var regionName: String? = "USA"
    var regionID: Int = 1
    var systemShortName: String? = "SNES"
    var language: String? = "English"

    /// Default aspect ratio for SNES games
    var boxArtAspectRatio: CGFloat { 1.0 }

    var debugDescription: String? {
        """
        Mock Game Debug Info:
        ID: \(id)
        System: \(systemIdentifier)
        ROM Path: \(romPath)
        MD5: \(md5Hash)
        CRC: \(crc)
        Import Date: \(importDate)
        """
    }
}
