//
//  LibrarySerializer.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 10/30/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

import Foundation
import PVSupport

public protocol Packageable {
    associatedtype PackageType: Package
    var packageType: SerializerPackageType { get }
    func toPackage() throws -> PackageType
}

public typealias JSONMetadataSerialable = DomainConvertibleType & LocalFileInfoProvider & DataProvider

extension Packageable where Self: JSONMetadataSerialable {
    internal func packageParts() throws -> (Data, Self.DomainType) {
        let data = try readData()
        return (data, asDomain())
    }
}

extension PVSaveState: Packageable {
    public var packageType: SerializerPackageType { return .saveState }

    public typealias PackageType = SavePackage
    public func toPackage() throws -> PackageType {
        let (data, metadata) = try packageParts()
        return SavePackage(data: data, metadata: metadata)
    }
}

extension PVGame: Packageable {
    public var packageType: SerializerPackageType { return .game }

    public typealias PackageType = GamePackage
    public func toPackage() throws -> GamePackage {
        let (data, metadata) = try packageParts()

        let saves = Array(saveStates).map { save -> SavePackage in
            let data = try! Data(contentsOf: save.file.url)
            let metadata = save.asDomain()
            return SavePackage(data: data, metadata: metadata)
        }

        let gamePackage = GamePackage(data: data, metadata: metadata, saves: saves)
        return gamePackage
    }
}

public typealias SerliazeCompletion = (_ result: PackageResult) -> Void
public typealias PackageCompletion = (_ result: PackageResult) -> Void

public final class LibrarySerializer {
    fileprivate init() {}

    private static let serializeQueue = DispatchQueue(label: "com.provenance.serializer", qos: .background)

    // MARK: - Metadata

    public static func storeMetadata<O: JSONMetadataSerialable>(_ object: O, completion: @escaping SerliazeCompletion) {
        let directory = object.url.deletingLastPathComponent()
        let fileName = object.fileName
        let data = object.asDomain()

        LibrarySerializer.serializeQueue.async {
            let jsonFilename = fileName + ".json"
            let saveURL = directory.appendingPathComponent(jsonFilename, isDirectory: true)
            do {
                try store(data, to: saveURL)
                completion(.success(saveURL))
            } catch {
                completion(.error(error))
            }
        }
    }

    // MARK: - Packaging

    public static func storePackage<P: Packageable & JSONMetadataSerialable>(_ object: P, completion: @escaping PackageCompletion) {
        let path = object.url
        let directory = path.deletingLastPathComponent()
        let fileName = object.fileName

        LibrarySerializer.serializeQueue.async {
            let jsonFilename = fileName + "." + object.packageType.extension
            let saveURL = directory.appendingPathComponent(jsonFilename, isDirectory: false)
            do {
                let package = try object.toPackage()
                try store(package, to: saveURL)
                completion(.success(saveURL))
            } catch {
                completion(.error(error))
            }
        }
    }
}

// MARK: Disk save / load

extension LibrarySerializer {
    /// Store an encodable struct to the specified directory on disk
    ///
    /// - Parameters:
    ///   - object: the encodable struct to store
    ///   - path: where to store the struct
    static func store<T: Encodable>(_ object: T, to url: URL) throws {
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(object)
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            FileManager.default.createFile(atPath: url.path, contents: data, attributes: nil)
        } catch {
            throw error
        }
    }

    /// Retrieve and convert a struct from a file on disk
    ///
    /// - Parameters:
    ///   - fileName: name of the file where struct data is stored
    ///   - directory: directory where struct data is stored
    ///   - type: struct type (i.e. Message.self)
    /// - Returns: decoded struct model(s) of data
    static func retrieve<T: Decodable>(_ url: URL, as type: T.Type) throws -> T {
        if !FileManager.default.fileExists(atPath: url.path) {
            fatalError("File at path \(url.path) does not exist!")
        }

        if let data = FileManager.default.contents(atPath: url.path) {
            let decoder = JSONDecoder()
            do {
                let model = try decoder.decode(type, from: data)
                return model
            } catch {
                ELOG(error.localizedDescription)
                throw error
            }
        } else {
            ELOG("No data at \(url.path)!")
            throw LibrarySerializerError.noDataAtPath(url)
        }
    }

    /// Remove specified file from specified directory
    static func remove(_ url: URL) {
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                fatalError(error.localizedDescription)
            }
        }
    }

    /// Returns BOOL indicating whether file exists at specified directory with specified file name
    static func fileExists(_ url: URL) -> Bool {
        return FileManager.default.fileExists(atPath: url.path)
    }
}
