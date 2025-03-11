//
//  Packageable.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 8/30/24.
//

import PVPrimitives
import PVRealm

public protocol Packageable {
    associatedtype PackageType: Package
    var packageType: SerializerPackageType { get }
    func toPackage() async throws -> PackageType?
}

public typealias JSONMetadataSerialable = DomainConvertibleType & LocalFileInfoProvider & DataProvider

//import CoreTransferable
//import UniformTypeIdentifiers
//@available(iOS 16.0, *)
//extension Transferable where Self: Packageable {
//    public typealias TransferRepresentation = PackageType
//    public static var transferRepresentation: TransferRepresentation {
//        CodableRepresentation(contentType: UTI.aliasFile)
//    }
//}

public extension Packageable where Self: JSONMetadataSerialable {
    internal func packageParts() async throws -> (Data?, Self.DomainType) {
        let data = try await readData()
        return (data, asDomain())
    }
}

extension PVSaveState: Packageable {
    public var packageType: SerializerPackageType { return .saveState }

    public typealias PackageType = SavePackage
    public func toPackage() async throws -> PackageType? {
        let (data, metadata) = try await packageParts()
        guard let data = data else { return nil }
        return SavePackage(data: data, metadata: metadata)
    }
}

extension PVGame: Packageable {
    public var packageType: SerializerPackageType { return .game }

    public typealias PackageType = GamePackage
    public func toPackage() async throws -> PackageType? {
        let (data, metadata) = try await packageParts()
        guard let data = data else { return nil }
        let saveStatesArray = Array(saveStates)
        let saves = await saveStatesArray.asyncCompactMap { save async -> SavePackage? in
            guard let url = save.file?.url else { return nil }
            guard let data = try? Data(contentsOf: url) else { return nil }
            let metadata = save.asDomain()
            return SavePackage(data: data, metadata: metadata)
        }

        let gamePackage = GamePackage(data: data, metadata: metadata, saves: saves)
        return gamePackage
    }
}
