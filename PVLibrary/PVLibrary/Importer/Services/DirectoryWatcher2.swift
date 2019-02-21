//
//  DirectoryWatcher.swift
//  Provenance
//
//  Created by James Addyman on 11/04/2013.
//  Copyright (c) 2013 Testut Tech. All rights reserved.
//

import Foundation
import Promises
import PVSupport
import RxCocoa
import RxSwift

public struct ExtractionProgress {
    let path: URL
    let completed: [URL]
    let current: ExtractionProgressEntry
    let total: Int
}

public extension ExtractionProgress {
    var progress: Float {
        let perFile: Float = 1.0 / Float(total)
        let base = Float(completed.count) * perFile
        let currentFile = current.progress * perFile
        return base + currentFile
    }
}

public struct ExtractionProgressEntry {
    let path: URL
    var progress: Float
}

public typealias PVExtractionStartedSubject = PublishSubject<URL>
public typealias PVExtractionUpdatedSubject = PublishSubject<ExtractionProgress>
public typealias PVExtractionCompleteSubjext = PublishSubject<[URL]?>

public enum DirectoryWatcherError: Error {
    case pathNotDirectory
    case pathAlreadyWatched
}

public final class DirectoryWatcher2 {
    public static let shared = DirectoryWatcher2()
    private init() {
//        watchedDirectories.asObservable().distinctUntilChanged({ return $0.count > $1.count }).fla
    }

    public let newFile = PublishSubject<URL>()

    private let disposeBag = DisposeBag()

    private var watchedDirectories = Variable<Set<URL>>(Set<URL>())

    public func watchDirectory(_ url: URL) throws {
        guard !watchedDirectories.value.contains(url) else { throw DirectoryWatcherError.pathAlreadyWatched }
        guard url.hasDirectoryPath else { throw DirectoryWatcherError.pathNotDirectory }

        if watchedDirectories.value.insert(url).inserted {
            serialQueue.async {
                do {
                    try self.initialScan(url)
                } catch {
                    ELOG("\(error)")
                }
            }

            _startMonitoring(url)
        }
    }

    public func unwatchDirectory(_ url: URL) {
        if let removed = watchedDirectories.value.remove(url) {
            _stopMonitoring(removed)
        }
    }

    struct WatchedDir {
        let url: URL
        let dispatchSource: DispatchSourceFileSystemObject
        var previousContents: Set<URL>?
    }

    fileprivate var dispatch_sources = [URL: WatchedDir]()
    fileprivate let serialQueue: DispatchQueue = DispatchQueue(label: "com.provenance-emu.provenance.serialExtractorQueue")

    private func initialScan(_ url: URL) throws {
        let exts = PVEmulatorConfiguration.archiveExtensions
        let contents = try FileManager.default.contentsOfDirectory(at: url,
                                                                   includingPropertiesForKeys: nil,
                                                                   options: [.skipsHiddenFiles])
            .filter { exts.contains($0.pathExtension.lowercased()) }

        contents.forEach(newFileDetected(_:))
    }

    private func newFileDetected(_ path: URL) {
        newFile.onNext(path)
    }

    public func startMonitoring() {
        watchedDirectories.value.forEach(_startMonitoring(_:))
    }

    public func _startMonitoring(_ url: URL) {
        DLOG("Start Monitoring \(url.path)")
        _stopMonitoring(url)

        let fd: Int32 = open(url.path, O_EVTONLY)

        if fd == 0 {
            ELOG("Unable open file system ref \(url)")
            assertionFailure("Unable open file system ref \(url)")
            return
        }

        // makeReadSource or makeWriteSource
        let dispatch_source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write], queue: serialQueue) // makeWriteSource(fileDescriptor: fd, queue: serialQueue)
        dispatch_sources[url] = WatchedDir(url: url, dispatchSource: dispatch_source, previousContents: nil)

        dispatch_source.setRegistrationHandler {
            dispatch_source.setEventHandler(handler: {
                let contents = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
                let watchedDir = self.dispatch_sources[url]
                let previousContentsSet = watchedDir?.previousContents ?? Set<URL>()

                var contentsSet = Set(contents ?? [URL]())
                contentsSet.subtract(previousContentsSet)

                contentsSet = contentsSet.filter({ (url) -> Bool in
                    // Ignore special files
                    url.lastPathComponent != "0" && !url.lastPathComponent.starts(with: ".") && !url.path.contains("_MACOSX")
                })

                contentsSet.forEach { file in
                    self.watchFile(at: file)
                }

                if let aContents = contents {
                    self.dispatch_sources[url]?.previousContents = Set(aContents)
                }
            })

            dispatch_source.setCancelHandler(handler: {
                close(fd)
            })
        }

        dispatch_source.resume()
        // trigger the event watcher above to start an initial import on launch
        let triggerPath = url.appendingPathComponent("0")

        do {
            try "0".write(to: triggerPath, atomically: false, encoding: .utf8)
            try FileManager.default.removeItem(atPath: triggerPath.path)
        } catch {
            ELOG("\(error.localizedDescription)")
        }
    }

    public func stopMonitoring() {
        watchedDirectories.value.forEach(_stopMonitoring(_:))
    }

    private func _stopMonitoring(_ url: URL) {
        DLOG("Stop Monitoring \(url.path)")

        if let dispatch_source = self.dispatch_sources[url]?.dispatchSource {
            dispatch_source.cancel()
            dispatch_sources[url] = nil
        }
    }

    public func watchFile(at path: URL) {
        DLOG("Start watching \(path.lastPathComponent)")

        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: path.path)

            let filesize: UInt64 = attributes[FileAttributeKey.size] as? UInt64 ?? 0
            let immutable: Bool = attributes[FileAttributeKey.immutable] as? Bool ?? false
            print("immutable \(immutable)")

            DispatchQueue.main.async { [weak self] () -> Void in
                if let weakSelf = self {
                    Timer.scheduledTimer(timeInterval: 2.0, target: weakSelf, selector: #selector(DirectoryWatcher2.checkFileProgress(_:)), userInfo: ["path": path, "filesize": filesize, "wasZeroBefore": false], repeats: false)
                }
            }
        } catch {
            ELOG("Error getting file attributes for \(path.path)")
            return
        }
    }

    @objc
    func checkFileProgress(_ timer: Timer) {
        guard let userInfo = timer.userInfo as? [String: Any], let path = userInfo["path"] as? URL, let previousFilesize = userInfo["filesize"] as? UInt64 else {
            ELOG("Timer missing userInfo or elements of it.")
            return
        }

        let attributes: [FileAttributeKey: Any]
        do {
            attributes = try FileManager.default.attributesOfItem(atPath: path.path)
        } catch {
            ELOG("\(error.localizedDescription)")
            return
        }

        let currentFilesize: UInt64 = attributes[FileAttributeKey.size] as! UInt64

        // This is because webDAv will show 0 for both values on the first write
        let wasZeroBefore: Bool = userInfo["wasZeroBefore"] as! Bool

        let sizeHasntChanged = previousFilesize == currentFilesize

        if sizeHasntChanged, (currentFilesize > 0 || wasZeroBefore) {
            newFileDetected(path)
            return
        }

        Timer.scheduledTimer(timeInterval: 2.0, target: self, selector: #selector(DirectoryWatcher2.checkFileProgress(_:)), userInfo: ["path": path, "filesize": currentFilesize, "wasZeroBefore": (currentFilesize == 0)], repeats: false)
    }

    // Delay start so we have a moment to move files and stuff
    fileprivate func delayedStartMonitoring() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: {
            self.startMonitoring()
        })
    }
}
