//
//  PVBIOS.swift
//  Provenance
//
//  Created by Joseph Mattiello on 3/11/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import Foundation
import RealmSwift

@objcMembers
public final class PVBIOS: Object, PVFiled {
    dynamic public var system: PVSystem!
    dynamic public var descriptionText: String = ""
    dynamic public var optional: Bool = false

    dynamic public var expectedMD5: String = ""
    dynamic public var expectedSize: Int = 0
    dynamic public var expectedFilename: String = ""

    dynamic public var file: PVFile?

    public convenience init(withSystem system: PVSystem, descriptionText: String, optional: Bool = false, expectedMD5: String, expectedSize: Int, expectedFilename: String) {
        self.init()
        self.system = system
        self.descriptionText = descriptionText
        self.optional = optional
        self.expectedMD5 = expectedMD5
        self.expectedSize = expectedSize
        self.expectedFilename = expectedFilename
    }

    override public static func primaryKey() -> String? {
        return "expectedFilename"
    }
    
    public struct Status {
      
        public enum Mismatch {
            case md5(expected: String, actual: String)
            case size(expected: UInt, actual: UInt)
            case filename(expected: String, actual: String)
        }
        
        public enum State {
            case missing
            case mismatch([Mismatch])
            case match
        }
        
        let bios : PVBIOS
        
        let available : Bool
        let required : Bool
        let state : State
        
        init(withBios bios : PVBIOS) {
            self.bios = bios
            
            available = !(bios.file?.missing ?? true)
            if available {
                let md5Match = bios.file?.md5 == bios.expectedMD5
                let sizeMatch = bios.file?.size == UInt64(bios.expectedSize)
                let filenameMatch = bios.file?.fileName == bios.expectedFilename
                
                var misses = [Mismatch]()
                if !md5Match {
                    misses.append(.md5(expected: bios.expectedMD5, actual: bios.file?.md5 ?? "0"))
                }
                if !sizeMatch {
                    misses.append(.size(expected: UInt(bios.expectedSize), actual: UInt(bios.file?.size ?? 0)))
                }
                if !filenameMatch {
                    misses.append(.filename(expected: bios.expectedFilename, actual: bios.file?.fileName ?? "Nil"))
                }
                
                state = misses.isEmpty ? .match : .mismatch(misses)
            } else {
                state = .missing
            }
            required = !bios.optional
        }
    }
    
    public var status : Status {
        return Status(withBios: self)
    }
}

public class BiosFile : PVFile {
    
}

public extension PVBIOS {
    var expectedPath: URL {
        return system.biosDirectory.appendingPathComponent(expectedFilename, isDirectory: false)
    }
}
