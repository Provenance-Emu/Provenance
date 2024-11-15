//
//  Core.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 9/5/24.
//

#if canImport(SwiftData) && !os(tvOS)
import SwiftData
import PVLogging

//@Model
public class Core_Data {
//    @Attribute(.unique)
    public var identifier: String = ""

    public var principleClass: String = ""

    // Metadata
    public var projectName = ""
    public var projectURL = ""
    public var projectVersion = ""
    public var disabled = false
    
    // Links
//    @Reference(to: System_Data.self)
    var supportedSystems: [System_Data]
    
    // Reverse links
//    @Reference(to: SaveState_Data.self)
    public var saveStates: [SaveState_Data]
    
    init(identifier: String, principleClass: String, projectName: String = "", projectURL: String = "", projectVersion: String = "", disabled: Bool = false, supportedSystems: [System_Data], saveStates: [SaveState_Data]) {
        self.identifier = identifier
        self.principleClass = principleClass
        self.projectName = projectName
        self.projectURL = projectURL
        self.projectVersion = projectVersion
        self.disabled = disabled
        self.supportedSystems = supportedSystems
        self.saveStates = saveStates
    }
}

extension Core_Data {
    var hasCoreClass: Bool {
        let _class: AnyClass? = NSClassFromString(principleClass)
        DLOG("Class: \(String(describing: _class)) for \(principleClass)")
        return _class != nil
    }
}
#endif
