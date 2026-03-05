//
//  Core.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 9/5/24.
//

#if canImport(SwiftData)
import SwiftData
import PVLogging

@Model
public class Core_Data {
    @Attribute(.unique) public var identifier: String = ""
    public var principleClass: String = ""

    // Metadata
    public var projectName: String = ""
    public var projectURL: String = ""
    public var projectVersion: String = ""
    public var disabled: Bool = false

    // Many-to-many: cores support multiple systems (inverse declared on System_Data.cores)
    public var supportedSystems: [System_Data] = []

    // One-to-many: save states that used this core (inverse on SaveState_Data.core)
    @Relationship(deleteRule: .nullify, inverse: \SaveState_Data.core)
    public var saveStates: [SaveState_Data] = []

    public init(identifier: String, principleClass: String, projectName: String = "",
                projectURL: String = "", projectVersion: String = "", disabled: Bool = false,
                supportedSystems: [System_Data] = [], saveStates: [SaveState_Data] = []) {
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
    public var hasCoreClass: Bool {
        let _class: AnyClass? = NSClassFromString(principleClass)
        DLOG("Class: \(String(describing: _class)) for \(principleClass)")
        return _class != nil
    }
}
#endif
