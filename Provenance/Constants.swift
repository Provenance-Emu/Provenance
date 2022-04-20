//
//  Constants.swift
//  Provenance
//
//  Created by Joseph Mattiello on 4/20/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation

public enum Constants {
    public enum Links {
        static let wiki = URL(string: "https://wiki.provenance-emu.com/")!
    }
    
    public enum Strings {
        static let yes = NSLocalizedString("Yes", comment: "Yes")
        static let no = NSLocalizedString("No", comment: "No")
        static let refreshGameLibrary = NSLocalizedString("Refresh Game Library", comment: "Refresh Game Library") + "?"
        static let refreshGameLibraryMessage = """
Attempt to reload the artwork and title information for your entire library. This can be a slow process, especially for large libraries. Only do this if you really, really want to try and get more artwork or update the information.

You will need to completely relaunch the App to start the library rebuild process.
"""
        static let emptyImageCacheTitle = NSLocalizedString("Empty Image Cache?", comment: "")
        static let emptyImageCacheMessage = NSLocalizedString("Empty the image cache to free up disk space. Images will be redownloaded on demand.", comment: "")

    }
}

public extension URL {
    static let wiki: URL = Constants.Links.wiki
}

public extension String {
    static let no: String = Constants.Strings.no
    static let yes: String = Constants.Strings.yes
    static let refreshGameLibrary: String = Constants.Strings.refreshGameLibrary
}
