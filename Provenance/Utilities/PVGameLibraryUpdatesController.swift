//
//  PVGameLibraryUpdatesController.swift
//  Provenance
//
//  Created by Dan Berglund on 2020-06-11.
//  Copyright © 2020 Provenance Emu. All rights reserved.
//

import Foundation
import PVSupport
import PVLibrary
import RxSwift
import RxCocoa
import CoreSpotlight

// Responsible for handling updates to game library, finding conflicts and resolving them
struct PVGameLibraryUpdatesController {
    public let hudState: Observable<HudState>
    public let conflicts: Observable<[Conflict]>

    private let gameImporter: GameImporter
    private let gameImporterEvents: Observable<GameImporter.Event>
    private let updateConflicts = PublishSubject<Void>()

    enum HudState {
        case hidden
        case title(String)
        case titleAndProgress(title: String, progress: Float)
    }

    // TODO: Would be nice to inject the DirectoryWatcher as well
    init(gameImporter: GameImporter, importPath: URL = PVEmulatorConfiguration.Paths.romsImportPath, scheduler: SchedulerType = MainScheduler.asyncInstance) {
        self.gameImporter = gameImporter
        self.gameImporterEvents = Reactive(gameImporter).events.share()

        let directoryWatcher = RxDirectoryWatcher(directory: importPath)
        let directoryWatcherExtractedFiles = directoryWatcher.events.finishedExtracting(at: importPath)

        let initialScan: Observable<[URL]> = gameImporterEvents
            .filter { $0 == .initialized }
            .map { _ in try FileManager.default.contentsOfDirectory(at: importPath, includingPropertiesForKeys: nil, options: [.skipsPackageDescendants, .skipsSubdirectoryDescendants])}
            .filter { !$0.isEmpty }

        let filesToImport = Observable.merge(initialScan, directoryWatcherExtractedFiles)

        // We use a hacky combineLatest here since we need to do the bind to `gameImporter.startImport` somewhere, so we hack it into the hudState definition
        let o1 = Self.hudState(from: directoryWatcher, gameImporterEvents: gameImporterEvents, scheduler: scheduler)
        let o2 = filesToImport.do(onNext: gameImporter.startImport)
        hudState = Observable.combineLatest(o1, o2) { _hudState, _ in return _hudState }

        let gameImporterConflicts = gameImporterEvents
            .compactMap({ event -> Void? in
                if case .completed = event {
                    return ()
                }
                return nil
            })

        let systemDirsConflicts = Observable.just(PVSystem.all.map { $0 })
            .map({ systems -> [(System, [URL])] in
                systems
                    .map { $0.asDomain() }
                    .compactMap { system in
                        guard let candidates = FileManager.default.candidateROMs(for: system) else { return nil }
                        return (system, candidates)
                }
            })
            .flatMap({ systems -> Observable<Void> in
                Observable.concat(systems.map { system, paths in
                    Observable.create { observer in
                        gameImporter.getRomInfoForFiles(atPaths: paths, userChosenSystem: system)
                        observer.onCompleted()
                        return Disposables.create()
                    }
                })
            })

        let potentialConflicts = Observable.merge(gameImporterConflicts, systemDirsConflicts, updateConflicts).startWith(())

        conflicts = potentialConflicts
            .map { gameImporter.conflictedFiles ?? [] }
            .map({ filesInConflictsFolder -> [Conflict] in
                filesInConflictsFolder.map { file in
                    (
                        path: file,
                        candidates: PVSystem.all.filter { $0.supportedExtensions.contains(file.pathExtension.lowercased() )}.map { $0.asDomain() }
                    )
                }
            })
            .map { conflicts in conflicts.filter { !$0.candidates.isEmpty }}
            .share(replay: 1, scope: .forever)
    }

    #if os(iOS)
    func addImportedGames(to spotlightIndex: CSSearchableIndex, database: RomDatabase) -> Disposable {
        gameImporterEvents
            .compactMap({ event -> String? in
                if case .finished(let md5, _) = event {
                    return md5
                }
                return nil
            })
            .compactMap { database.realm.object(ofType: PVGame.self, forPrimaryKey: $0) }
            .map { game in CSSearchableItem(uniqueIdentifier: game.spotlightUniqueIdentifier, domainIdentifier: "org.provenance-emu.game", attributeSet: game.spotlightContentSet) }
            .observe(on: SerialDispatchQueueScheduler(qos: .background))
            .subscribe(onNext: { item in
                spotlightIndex.indexSearchableItems([item]) { error in
                    if let error = error {
                        ELOG("indexing error: \(error)")
                    }
                }
            })
    }
    #endif

    private static func hudState(from directoryWatcher: RxDirectoryWatcher, gameImporterEvents: Observable<GameImporter.Event>, scheduler: SchedulerType) -> Observable<HudState> {
        let stateFromGameImporter = gameImporterEvents
            .compactMap({ event -> HudState? in
                switch event {
                case .initialized, .finishedArtwork, .completed:
                    return nil
                case .started(let path):
                    return .title("Importing: \(path.lastPathComponent)")
                case .finished:
                    return .hidden
                }
            })

        func labelMaker(_ path: URL) -> String {
            #if os(tvOS)
            return "Extracting Archive: \(path.lastPathComponent)"
            #else
            return "Extracting Archive…"
            #endif
        }

        let stateFromDirectoryWatcher = directoryWatcher.events
            .flatMap({ event -> Observable<HudState> in
                switch event {
                case .started(let path):
                    return .just(.titleAndProgress(title: labelMaker(path), progress: 0))
                case .updated(let path, let progress):
                    return .just(.titleAndProgress(title: labelMaker(path), progress: progress))
                case .completed(let paths):
                    return Observable.merge(
                        .just(.titleAndProgress(title: paths != nil ? "Extraction Complete!" : "Extraction Failed.", progress: 1)),
                        Observable.just(.hidden).delay(.milliseconds(500), scheduler: scheduler)
                    )
                }
            })

        return Observable.merge(stateFromGameImporter, stateFromDirectoryWatcher)
    }
}

extension PVGameLibraryUpdatesController: ConflictsController {
    func resolveConflicts(withSolutions solutions: [URL : System]) {
        gameImporter.resolveConflicts(withSolutions: solutions)
        updateConflicts.onNext(())
    }
}

private extension Observable where Element == RxDirectoryWatcher.Event {
    // Emits the url:s once all archives has been extracted
    func finishedExtracting(at path: URL) -> Observable<[URL]> {
        return compactMap({ event -> [URL]? in
            if case .completed(let paths) = event {
                return paths
            }
            return nil
        })
        .scan((extracted: [], extractionComplete: false), accumulator: { acc, extracted -> (extracted: [URL], extractionComplete: Bool) in
            let allExtracted = acc.extracted + extracted
            do {
                let remainingFiles = try FileManager.default.contentsOfDirectory(at: path, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
                return (
                    extracted: allExtracted,
                    extractionComplete: remainingFiles.filter { $0.isArchive }.isEmpty
                )
            } catch {
                ELOG("\(error.localizedDescription)")
                return (
                    extracted: allExtracted,
                    extractionComplete: false
                )
            }
        })
        .filter { $0.extractionComplete }
        .map { $0.extracted }
    }
}

private extension FileManager {
    /// Returns a list of all the files in a systems directory that are potential ROMs (AKA has the correct extension)
    func candidateROMs(for system: System) -> [URL]? {
        let systemDir = system.romsDirectory

        // Check if a folder actually exists, nothing to do if it doesn't
        guard fileExists(atPath: systemDir.path) else {
            VLOG("Nothing found at \(systemDir.path)")
            return nil
        }
        guard let contents = try? contentsOfDirectory(at: systemDir, includingPropertiesForKeys: nil, options: [.skipsSubdirectoryDescendants, .skipsHiddenFiles]),
            !contents.isEmpty else {
                return nil
        }

        return contents.filter { system.extensions.contains($0.pathExtension) }
    }
}

private extension GameImporter {
    enum Event: Equatable {
        case initialized
        case started(path: URL)
        case finished(md5: String, modified: Bool)
        case finishedArtwork(url: URL)
        case completed(encounteredConflicts: Bool)
    }
}

private extension Reactive where Base: GameImporter {
    var events: Observable<GameImporter.Event> {
        return Observable.create { observer in
            self.base.initialized.notify(queue: DispatchQueue.global(qos: .background)) {
                observer.onNext(.initialized)
            }

            self.base.importStartedHandler = { observer.onNext(.started(path: URL(fileURLWithPath: $0))) }
            self.base.finishedImportHandler = { observer.onNext(.finished(md5: $0, modified: $1)) }
            self.base.finishedArtworkHandler = { observer.onNext(.finishedArtwork(url: URL(fileURLWithPath: $0))) }
            self.base.completionHandler = { observer.onNext(.completed(encounteredConflicts: $0)) }

            return Disposables.create {
                self.base.importStartedHandler = nil
                self.base.finishedImportHandler = nil
                self.base.finishedArtworkHandler = nil
                self.base.completionHandler = nil
            }
        }
    }
}

private struct RxDirectoryWatcher {
    enum Event {
        case started(path: URL)
        case updated(path: URL, progress: Float)
        case completed(paths: [URL]?)
    }
    let events: Observable<Event>
    init(directory: URL) {
        events = Observable.create { observer in
            let internalWatcher = DirectoryWatcher(directory: directory,
                                                   extractionStartedHandler: { observer.onNext(.started(path: $0)) },
                                                   extractionUpdatedHandler: { observer.onNext(.updated(path: $0, progress: $3)) },
                                                   extractionCompleteHandler: { observer.onNext(.completed(paths: $0)) })
            internalWatcher.startMonitoring()
            return Disposables.create {
                internalWatcher.stopMonitoring()
            }
        }.share()
    }
}

private extension URL {
    var isArchive: Bool {
        PVEmulatorConfiguration.archiveExtensions.contains(pathExtension.lowercased())
    }
}
