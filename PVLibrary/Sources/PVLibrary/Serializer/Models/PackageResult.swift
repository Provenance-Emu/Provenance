//
//  PackageResult.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 12/26/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

import Foundation

public enum PackageResult {
    case success(URL)
    case error(Error)
}
