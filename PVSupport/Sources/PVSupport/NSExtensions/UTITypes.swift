//
//  UTITypes.swift
//  
//
//  Created by Joseph Mattiello on 3/7/23.
//

import Foundation

import UniformTypeIdentifiers

// also declare the content type in the Info.plist
@available(iOS 14.0, tvOS 14.0, *)
extension UTType {
	static var saveState: UTType = UTType(exportedAs: "com.provenance.savestate")
	static var artwork: UTType = UTType(exportedAs: "com.provenance.artwork")
	static var rom: UTType = UTType(exportedAs: "com.provenance.rom")
}
