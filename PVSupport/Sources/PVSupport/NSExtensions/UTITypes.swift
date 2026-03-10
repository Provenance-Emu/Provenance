//
//  UTITypes.swift
//
//
//  Created by Joseph Mattiello on 3/7/23.
//

import Foundation

#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers

// also declare the content type in the Info.plist
@available(iOS 14.0, tvOS 14.0, *)
extension UTType {
    // Provenance-owned types (UTExportedTypeDeclarations in Info.plist)
    // Note: rom, artwork, cheat, savestate are declared in PVPrimitives/UTI.swift
    static var retroarchConfigFile: UTType { UTType(exportedAs: "com.provenance.retroarch.config") }
}
#endif
