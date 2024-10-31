//
//  URKArchiveTestCase.swift
//  UnrarKit Tests
//
//  Created by Dov Frankel on 8/1/22.
//

import Foundation

@objc public extension URKArchiveTestCase {
    
    var machineHardwareName: String? {
        var sysinfo = utsname()
        guard uname(&sysinfo) == EXIT_SUCCESS else { return nil }
        
        let data = Data(bytes: &sysinfo.machine, count: Int(_SYS_NAMELEN))
        guard let identifier = String(bytes: data, encoding: .ascii) else { return nil }
        return identifier.trimmingCharacters(in: .controlCharacters)
    }
    
}
