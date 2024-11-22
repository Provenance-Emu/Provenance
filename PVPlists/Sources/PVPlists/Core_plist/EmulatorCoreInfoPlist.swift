//
//  EmulatorCoreInfoPlist.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 8/6/24.
//

import Foundation
import PVLogging

@objc
@objcMembers
public final class EmulatorCoreInfoPlist: NSObject, Sendable {
    public let identifier: String
    public let principleClass: String

    public let supportedSystems: [String]

    public let projectName: String
    public let projectURL: String
    public let projectVersion: String
    public let disabled: Bool
    public let appStoreDisabled: Bool
    public let subCores:  [EmulatorCoreInfoPlist]?

    public init(identifier: String, principleClass: String, supportedSystems: [String], projectName: String, projectURL: String, projectVersion: String, disabled: Bool = false, appStoreDisabled: Bool = false, subCores: [EmulatorCoreInfoPlist]? = nil) {
        self.identifier = identifier
        self.principleClass = principleClass
        self.supportedSystems = supportedSystems
        self.projectName = projectName
        self.projectURL = projectURL
        self.projectVersion = projectVersion
        self.disabled = disabled
        self.appStoreDisabled = appStoreDisabled
        self.subCores = subCores
    }

    public init?(fromInfoDictionary dict: [String: Any]) {
        /// Identifier
        guard let identifier = dict["PVCoreIdentifier"] as? String else {
            return nil
        }
        self.identifier = identifier

        /// Principle Class
        guard let principleClass = dict["PVPrincipleClass"] as? String else {
            return nil
        }
        self.principleClass = principleClass

        /// Supported systems
        guard let supportedSystems = dict["PVSupportedSystems"] as? [String] else {
            return nil
        }
        self.supportedSystems = supportedSystems

        /// Project name
        guard let projectName = dict["PVProjectName"] as? String else {
            return nil
        }
        self.projectName = projectName

        /// Project URL
        guard let projectURL = dict["PVProjectURL"] as? String else {
            return nil
        }
        self.projectURL = projectURL

        /// Project Version
        guard let projectVersion = dict["PVProjectVersion"] as? String else {
            return nil
        }
        self.projectVersion = projectVersion

        /// Disabled
        self.disabled = dict["PVDisabled"] as? Bool ?? false

        /// AppStore Disabled
        self.appStoreDisabled = dict["PVAppStoreDisabled"] as? Bool ?? false

        /// Subcores
        if let subCores = dict["PVCores"] as? [[String:Any]] {
            self.subCores = subCores.compactMap {
                return Self.init(fromInfoDictionary: $0)
            }
        } else {
            self.subCores = nil
        }
    }

    public convenience init?(fromURL plistPath: URL) throws {
        guard let data = try? Data(contentsOf: plistPath) else {
            ELOG("Could not read Core.plist")
            throw EmulatorCoreInfoPlistError.couldNotReadPlist
        }

        guard let plistObject = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            ELOG("Could not generate parse Core.plist")
            throw EmulatorCoreInfoPlistError.couldNotParsePlist
        }

        self.init(fromInfoDictionary: plistObject)
    }
}

public extension EmulatorCoreInfoPlist {
    convenience init(_ corePlistEntry: CorePlistEntry) {
        let e = corePlistEntry
        let subCores = corePlistEntry.PVCores?.map { EmulatorCoreInfoPlist($0) }
        self.init(identifier: e.PVCoreIdentifier, principleClass: e.PVPrincipleClass, supportedSystems: e.PVSupportedSystems, projectName: e.PVProjectName, projectURL: e.PVProjectURL, projectVersion: e.PVProjectVersion, disabled: e.PVDisabled ?? false, appStoreDisabled: e.PVAppStoreDisabled ?? false, subCores: subCores)
    }
}

func ==(lhs: EmulatorCoreInfoPlist, rhs: CorePlistEntry) -> Bool {
    let subCores: [EmulatorCoreInfoPlist]? = rhs.PVCores?.map { EmulatorCoreInfoPlist($0) }

    return lhs.identifier == rhs.PVCoreIdentifier
    && lhs.principleClass == rhs.PVPrincipleClass
    && lhs.supportedSystems == rhs.PVSupportedSystems
    && lhs.projectName == rhs.PVProjectName
    && lhs.projectURL == rhs.PVProjectURL
    && lhs.projectVersion == rhs.PVProjectVersion
    && lhs.disabled == rhs.PVDisabled
    && lhs.appStoreDisabled == rhs.PVAppStoreDisabled
    && lhs.subCores == subCores
}
