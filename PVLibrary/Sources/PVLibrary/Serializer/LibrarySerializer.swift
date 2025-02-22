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
import PVPrimitives

public typealias SerliazeCompletion = @Sendable (_ result: PackageResult) -> Void

public final class LibrarySerializer {
    fileprivate init() {}

    private static let serializeQueue = DispatchQueue(label: "com.provenance.serializer", qos: .background)

    // MARK: - Metadata

    
    public static func storeMetadata<O: JSONMetadataSerialable>(_ object: O, completion: @escaping SerliazeCompletion) where O.DomainType: Sendable {
        guard let directory = object.url?.deletingLastPathComponent() else {
            completion(.error(LibrarySerializerError.noFile))
            return
        }
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

    public static func storePackage<P: Packageable & JSONMetadataSerialable & Sendable>(_ object: P) async throws -> URL? {
        guard  let path = object.url else { return nil }
        let directory = path.deletingLastPathComponent()
        let fileName = object.fileName

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
