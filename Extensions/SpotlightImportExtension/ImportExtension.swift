//
//  ImportExtension.swift
//  SpotlightImportExtension
//
//  Created by Joseph Mattiello on 11/12/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import CoreSpotlight

// https://developer.apple.com/documentation/corespotlight/csimportextension

class ImportExtension: CSImportExtension {
    
    override func update(_ attributes: CSSearchableItemAttributeSet, forFileAt: URL) throws {
        // Add attributes that describe the file at contentURL.
        // Throw an error with details on failure.
    }
    
}
