//
//  PVGameLibrary+Migration.swift
//  PVLibrary
//
//  Created by Dan Berglund on 2020-06-02.
//  Copyright © 2020 Provenance Emu. All rights reserved.
//

import Foundation
import RxSwift
import PVSupport
import PVLogging

extension PVGameLibrary {
    public enum MigrationEvent {
        case starting
        case pathsToImport(paths: [URL])
    }

    public enum MigrationError: Error {
        case unableToCreateRomsDirectory(error: Error)
        case unableToGetContentsOfDocuments(error: Error)
        case unableToGetRomPaths(error: Error)
    }
    // This method is probably outdated
    public func migrate(fileManager: FileManager = .default) -> Observable<MigrationEvent> {

        let libraryPath: String = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        let libraryURL = URL(fileURLWithPath: libraryPath)
        let toDelete = ["PVGame.sqlite", "PVGame.sqlite-shm", "PVGame.sqlite-wal"].map { libraryURL.appendingPathComponent($0) }

        let deleteDatabase = Completable
            .concat(toDelete
                        .map { path in
                            fileManager.rx
                                .removeItem(at: path)
                                .catch { error in
                                    ILOG("Unable to delete \(path) because \(error.localizedDescription)")
                                    return .empty()
                                }
                        })

        let createDirectory = fileManager.rx
            .createDirectory(at: PVEmulatorConfiguration.Paths.romsImportPath, withIntermediateDirectories: true, attributes: nil)
            .catch { .error(MigrationError.unableToCreateRomsDirectory(error: $0)) }

        // Move everything that isn't a realm file, into the the import folder so it wil be re-imported
        let moveFiles: Completable = fileManager.rx
            .contentsOfDirectory(at: PVEmulatorConfiguration.documentsPath, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
            .catch { Single<[URL]>.error(MigrationError.unableToGetContentsOfDocuments(error: $0)) }
            .map({ contents -> [URL] in
                let ignoredExtensions = ["jpg", "png", "gif", "jpeg"]
                return contents.filter { (url) -> Bool in
                    let dbFile = url.path.lowercased().contains("realm")
                    let ignoredExtension = ignoredExtensions.contains(url.pathExtension)
                    var isDir: ObjCBool = false
                    let exists: Bool = fileManager.fileExists(atPath: url.path, isDirectory: &isDir)
                    return exists && !dbFile && !ignoredExtension && !isDir.boolValue
                }
            })
            .flatMapCompletable({ filesToMove -> Completable in
                let moves = filesToMove
                    .map { ($0, PVEmulatorConfiguration.Paths.romsImportPath.appendingPathComponent($0.lastPathComponent))}
                    .map { path, toPath in
                        fileManager.rx.moveItem(at: path, to: toPath)
                            .catch({ error in
                                ELOG("Unable to move \(path.path) to \(toPath.path) because \(error.localizedDescription)")
                                return .empty()
                            })
                }
                return Completable.concat(moves)
            })

        let getRomPaths: Observable<MigrationEvent> = fileManager.rx
            .contentsOfDirectory(at: PVEmulatorConfiguration.Paths.romsImportPath, includingPropertiesForKeys: nil, options: [.skipsSubdirectoryDescendants, .skipsHiddenFiles])
            .catch { Single<[URL]>.error(MigrationError.unableToGetRomPaths(error: $0)) }
            .flatMapMaybe({ paths in
                if paths.isEmpty {
                    return .empty()
                } else {
                    return .just(.pathsToImport(paths: paths))
                }
            })
            .asObservable()

        return deleteDatabase
            .andThen(createDirectory)
            .andThen(moveFiles)
            .andThen(getRomPaths)
            .startWith(.starting)
    }
}

extension PVGameLibrary.MigrationError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unableToCreateRomsDirectory(let error):
            return "Unable to create roms directory, error: \(error.localizedDescription)"
        case .unableToGetContentsOfDocuments(let error):
            return "Unable to get contents of directory, error: \(error.localizedDescription)"
        case .unableToGetRomPaths(let error):
            return "Unable to get rom paths, error: \(error.localizedDescription)"
        }
    }
}

private extension Reactive where Base: FileManager {
    func removeItem(at path: URL) -> Completable {
        Completable.create { observer in
            do {
                if self.base.fileExists(atPath: path.path) {
                    try self.base.removeItem(at: path)
                }
                observer(.completed)
            } catch {
                observer(.error(error))
            }
            return Disposables.create()
        }
    }

    func createDirectory(at path: URL, withIntermediateDirectories: Bool, attributes: [FileAttributeKey: Any]?) -> Completable {
        Completable.create { observer in
            do {
                if !self.base.fileExists(atPath: path.path) {
                    try self.base.createDirectory(at: path, withIntermediateDirectories: withIntermediateDirectories, attributes: attributes)
                }

                observer(.completed)
            } catch {
                observer(.error(error))
            }
            return Disposables.create()
        }
    }

    func contentsOfDirectory(at path: URL, includingPropertiesForKeys: [URLResourceKey]?, options: Base.DirectoryEnumerationOptions) -> Single<[URL]> {
        Single.create { observer in
            do {
                let urls = try self.base.contentsOfDirectory(at: path, includingPropertiesForKeys: includingPropertiesForKeys, options: options)
                observer(.success(urls))
            } catch {
                observer(.failure(error))
            }
            return Disposables.create()
        }
    }

    func moveItem(at path: URL, to destination: URL) -> Completable {
        Completable.create { observer in
            do {
                try self.base.moveItem(at: path, to: destination)
                observer(.completed)
            } catch {
                observer(.error(error))
            }
            return Disposables.create()
        }
    }
}
