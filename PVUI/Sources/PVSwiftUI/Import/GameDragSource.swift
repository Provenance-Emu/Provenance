//
//  GameDragSource.swift
//  PVUI
//
//  Created by Provenance Emu on 2026-03-22.
//  Copyright 2026 Provenance Emu. All rights reserved.
//
//  NSItemProvider-based drag-out source for ROM files from the game library.
//  Part of issue #2136: Add Drag & Drop support to library, saves etc.
//
//  iOS/iPadOS/macCatalyst only — onDrag is unavailable on tvOS.
//

#if os(iOS)
import Foundation
import SwiftUI
import UniformTypeIdentifiers
import PVLogging
import PVRealm
import RealmSwift

// MARK: - View modifier

/// Adds drag-source behaviour to a game cell.
///
/// When the user long-presses and drags the view, an `NSItemProvider` is created
/// that vends the on-disk ROM file as a `public.file-url`.  Recipients such as
/// the Files app, or another Provenance instance, can consume the file directly.
///
/// The Realm lookup is deferred until the drag session begins, keeping
/// `GameItemPresentableView` free of live Realm bindings.
public struct GameDragSourceModifier: ViewModifier {
    /// MD5 hash used as the Realm primary key for `PVGame`.
    let gameMD5: String

    public init(gameMD5: String) {
        self.gameMD5 = gameMD5
    }

    public func body(content: Content) -> some View {
        content
            .onDrag {
                makeItemProvider()
            }
    }

    // MARK: - NSItemProvider factory

    /// Builds an `NSItemProvider` that lazily loads the ROM file URL.
    ///
    /// Returns an empty provider (no registered types) when the ROM is not
    /// found on disk so the drag simply does nothing — no crash, no alert.
    private func makeItemProvider() -> NSItemProvider {
        let provider = NSItemProvider()

        // Register a file URL representation.
        // `loadItem` on the receiving side will get back the NSURL.
        provider.registerFileRepresentation(
            forTypeIdentifier: UTType.fileURL.identifier,
            fileOptions: [],
            visibility: .all
        ) { completion in
            let fileURL = Self.resolveFileURL(forMD5: self.gameMD5)
            if let url = fileURL {
                completion(url, false, nil)
            } else {
                WLOG("GameDragSource: no on-disk ROM found for MD5 \(self.gameMD5)")
                completion(nil, false, nil)
            }
            return nil
        }

        return provider
    }

    // MARK: - File URL resolution

    /// Looks up the ROM file URL from Realm.
    /// Safe to call from the main thread — Realm reads are synchronous.
    private static func resolveFileURL(forMD5 md5: String) -> URL? {
        // Try multiple casings as the primary key may be stored upper or lower.
        let realm = RomDatabase.sharedInstance.realm
        let candidates = [md5, md5.uppercased(), md5.lowercased()]
        var seen = Set<String>()
        for key in candidates where seen.insert(key).inserted {
            if let game = realm.object(ofType: PVGame.self, forPrimaryKey: key),
               let url = game.file?.url,
               FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }
        return nil
    }
}

// MARK: - View extension

public extension View {
    /// Attaches a ROM drag-source to this view.
    ///
    /// When the user initiates a drag, the ROM file at the given MD5 is resolved
    /// from the local Realm database and offered to the drop target as a
    /// `public.file-url`.
    ///
    /// Guard: iOS/iPadOS/macCatalyst only — do not call on tvOS or watchOS.
    ///
    /// - Parameter gameMD5: The MD5 hash used as the primary key in `PVGame`.
    func romDragSource(gameMD5: String) -> some View {
        modifier(GameDragSourceModifier(gameMD5: gameMD5))
    }
}
#endif // os(iOS)
