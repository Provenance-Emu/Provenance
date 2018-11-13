//
//  LibrarySerializer.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 10/30/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

import Foundation
import PVSupport

public struct SavePackage : Codable {
    public let data : Data
    public let metadata : SaveState
}

public struct GamePackage : Codable {
    public let data : Data
    public let metadata : Game
    public let saves : [SavePackage]
}

public enum PackageResult {
    case success(URL)
    case error(Error)
}

public enum LibrarySerializerError : Error {
    case noDataAtPath(URL)
}

public typealias SerliazeCompletion = (_ result : PackageResult)->Void
public typealias PackageCompletion = (_ result : PackageResult)->Void

public final class LibrarySerializer {
    fileprivate init() { }


    static private let serializeQueue = DispatchQueue(label: "com.provenance.serializer", qos: .background)

    static public func serialize(_ save : PVSaveState, completion: @escaping SerliazeCompletion) {
        let directory = save.file.url.deletingLastPathComponent()
        let fileName = save.file.fileName
        let data = save.asDomain()

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

    static public func package(_ save : PVSaveState, completion: @escaping PackageCompletion) {
        let path = save.file.url
        let directory = path.deletingLastPathComponent()
        let fileName = save.file.fileNameWithoutExtension
        let metadata = save.asDomain()

        LibrarySerializer.serializeQueue.async {

            let jsonFilename = fileName + ".psvsave"
            let saveURL = directory.appendingPathComponent(jsonFilename, isDirectory: false)
            do {
                let data = try Data(contentsOf: path)
                let package = SavePackage(data: data, metadata: metadata)

                try store(package, to: saveURL)
                completion(.success(saveURL))
            } catch {
                completion(.error(error))
            }
        }
    }

    static public func package(_ game : PVGame, completion: @escaping PackageCompletion) {
        let directory = game.file.url.deletingLastPathComponent()
        let fileName = game.file.fileNameWithoutExtension
        let romPath = game.file.url

        let gameMetadata = game.asDomain()

        let saves = Array(game.saveStates).map { save -> SavePackage in
            let data = try! Data(contentsOf: save.file.url)
            let metadata = save.asDomain()
            return SavePackage(data: data, metadata: metadata)
        }

        LibrarySerializer.serializeQueue.async {

            let jsonFilename = fileName + ".pvrom"
            let saveURL = directory.appendingPathComponent(jsonFilename, isDirectory: false)
            do {
                let gameData = try Data(contentsOf: romPath)

                let gamePackage = GamePackage(data: gameData, metadata: gameMetadata, saves: saves)
                try store(gamePackage, to: saveURL)
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
    static func remove(_ url : URL) {
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                fatalError(error.localizedDescription)
            }
        }
    }

    /// Returns BOOL indicating whether file exists at specified directory with specified file name
    static func fileExists(_ url : URL) -> Bool {
        return FileManager.default.fileExists(atPath: url.path)
    }
}
