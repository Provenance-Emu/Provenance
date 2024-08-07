//
//  LibrarySerializer.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 10/30/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

import Foundation
import PVSupport
import PVLogging

public protocol Packageable {
    associatedtype PackageType: Package
    var packageType: SerializerPackageType { get }
    func toPackage() async throws -> PackageType
}

public typealias JSONMetadataSerialable = DomainConvertibleType & LocalFileInfoProvider & DataProvider

extension Packageable where Self: JSONMetadataSerialable {
    internal func packageParts() async throws -> (Data, Self.DomainType) {
        let data = try await readData()
        return await (data, asDomain())
    }
}

extension PVSaveState: Packageable {
    public var packageType: SerializerPackageType { return .saveState }

    public typealias PackageType = SavePackage
    public func toPackage() async throws -> PackageType {
        let (data, metadata) = try await packageParts()
        return SavePackage(data: data, metadata: metadata)
    }
}

extension Sequence {
    func asyncMap<T>(
        _ transform: (Self.Element) async throws -> T
    ) async rethrows -> [T] {
        var values = [T]()

        for element in self {
            try await values.append(transform(element))
        }

        return values
    }
}

extension Sequence {
    func concurrentMap<T>(
        _ transform: @escaping (Self.Element) async throws -> T
    ) async throws -> [T] {
        let tasks = map { element in
            Task {
                try await transform(element)
            }
        }

        return try await tasks.asyncMap { task in
            try await task.value
        }
    }
}

extension Sequence {
    func asyncForEach(
        _ operation: (Self.Element) async throws -> Void
    ) async rethrows {
        for element in self {
            try await operation(element)
        }
    }
}

extension Sequence {
    func concurrentForEach(
        _ operation: @escaping (Self.Element) async -> Void
    ) async {
        // A task group automatically waits for all of its
        // sub-tasks to complete, while also performing those
        // tasks in parallel:
        await withTaskGroup(of: Void.self) { group in
            for element in self {
                group.addTask {
                    await operation(element)
                }
            }
        }
    }
}

extension PVGame: Packageable {
    public var packageType: SerializerPackageType { return .game }

    public typealias PackageType = GamePackage
    public func toPackage() async throws -> GamePackage {
        let (data, metadata) = try await packageParts()
        let saveStatesArray = Array(saveStates)
        let saves = await saveStatesArray.asyncMap { save async -> SavePackage in
            let data = try! await Data(contentsOf: save.file.url)
            let metadata = await save.asDomain()
            return SavePackage(data: data, metadata: metadata)
        }

        let gamePackage = GamePackage(data: data, metadata: metadata, saves: saves)
        return gamePackage
    }
}

public typealias SerliazeCompletion = @Sendable (_ result: PackageResult) -> Void

public final class LibrarySerializer {
    fileprivate init() {}

    private static let serializeQueue = DispatchQueue(label: "com.provenance.serializer", qos: .background)

    // MARK: - Metadata

    
    public static func storeMetadata<O: JSONMetadataSerialable>(_ object: O, completion: @escaping SerliazeCompletion) async {
        let directory = await object.url.deletingLastPathComponent()
        let fileName = await object.fileName
        let data = await object.asDomain()

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

    public static func storePackage<P: Packageable & JSONMetadataSerialable & Sendable>(_ object: P) async throws -> URL {
        let path = await object.url
        let directory = path.deletingLastPathComponent()
        let fileName = await object.fileName

        return try await Task {
            let jsonFilename = fileName + "." + object.packageType.extension
            let saveURL = directory.appendingPathComponent(jsonFilename, isDirectory: false)
            let package = try await object.toPackage()
            try store(package, to: saveURL)
            return saveURL
        }.value
    }
}

// MARK: Disk save / load

public extension LibrarySerializer {
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
