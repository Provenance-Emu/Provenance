//
//  NSItemProvider+FileURL.swift
//  PVUI
//
//  Created by Provenance Emu on 2026-03-23.
//  Copyright 2026 Provenance Emu. All rights reserved.
//
//  Shared helper for resolving a `public.file-url` item-provider payload to a URL.
//  Used by both `ROMDropDelegate` and `SaveBundleDropModifier` to avoid duplication.
//
//  iOS/iPadOS/macCatalyst only.
//

#if os(iOS)
import Foundation

extension NSItemProvider {
    /// Resolves a `public.file-url` payload (returned by `loadItem(forTypeIdentifier:)`) to a `URL`.
    ///
    /// The system can deliver the URL as a `URL`, `NSURL`, or raw `Data` (URL data representation)
    /// depending on the drop source. This helper normalises all three cases.
    ///
    /// - Parameter item: The `NSSecureCoding?` value delivered by `loadItem`.
    /// - Returns: The resolved `URL`, or `nil` when the item cannot be interpreted as a file URL.
    static func fileURL(fromLoadedItem item: NSSecureCoding?) -> URL? {
        if let url = item as? URL {
            return url
        } else if let nsurl = item as? NSURL {
            return nsurl as URL
        } else if let data = item as? Data {
            return URL(dataRepresentation: data, relativeTo: nil)
        }
        return nil
    }
}
#endif // os(iOS)
