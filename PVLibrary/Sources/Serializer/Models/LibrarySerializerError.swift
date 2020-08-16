//
//  LibrarySerializerError.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 12/26/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

import Foundation

public enum LibrarySerializerError: Error {
    case noDataAtPath(URL)
}
