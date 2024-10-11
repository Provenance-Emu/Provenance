//
//  DirectoryWatcher.swift
//  Provenance
//
//  Created by James Addyman on 11/04/2013.
//  Copyright (c) 2013 Testut Tech. All rights reserved.
//

import Foundation
import PVLogging
import Extractor
import PVEmulatorCore
import PVFileSystem
@_exported import PVSupport
import SWCompression
@_exported import ZipArchive
import Combine

public typealias PVExtractionStartedHandler = (_ path: URL) -> Void
public typealias PVExtractionUpdatedHandler = (_ path: URL, _ entryNumber: Int, _ total: Int, _ progress: Float) -> Void
public typealias PVExtractionCompleteHandler = (_ paths: [URL]?) -> Void

public extension NSNotification.Name {
    static let PVArchiveInflationFailed = NSNotification.Name(rawValue: "PVArchiveInflationFailedNotification")
}

@Observable
public final class DirectoryWatcher {
    private let watchedDirectory: URL
    
    private let extractionStartedHandler: PVExtractionStartedHandler?
    private let extractionUpdatedHandler: PVExtractionUpdatedHandler?
    private let extractionCompleteHandler: PVExtractionCompleteHandler?
    
    fileprivate var dispatch_source: DispatchSourceFileSystemObject?
    fileprivate let serialQueue: DispatchQueue = .init(label: "org.provenance-emu.provenance.serialExtractorQueue")
    
    fileprivate var previousContents: [URL]?
    private var unzippedFiles = [URL]()
    
    public init(directory: URL, extractionStartedHandler startedHandler: PVExtractionStartedHandler?, extractionUpdatedHandler updatedHandler: PVExtractionUpdatedHandler?, extractionCompleteHandler completeHandler: PVExtractionCompleteHandler?) {
        watchedDirectory = directory
        
        var isDirectory: ObjCBool = false
        let fileExists: Bool = FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory)
        if (fileExists == false) || (isDirectory.boolValue == false) {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
            } catch {
                DLOG("Unable to create directory at: \(directory.path), because: \(error.localizedDescription)")
            }
        }
        
        unzippedFiles = [URL]()
        
        extractionStartedHandler = startedHandler
        extractionUpdatedHandler = updatedHandler
        extractionCompleteHandler = completeHandler
                
        serialQueue.async {
            Task {
                do {
                    let contents = try FileManager.default.contentsOfDirectory(at: directory,
                                                                               includingPropertiesForKeys: nil,
                                                                               options: [.skipsHiddenFiles])
                    await contents.asyncForEach { file in
                        let exts = Extensions.archiveExtensions
                        let ext = file.pathExtension.lowercased()
                        if exts.contains(ext) {
                            await self.extractArchive(at: file)
                        }
                    }
                } catch {
                    ELOG("\(error.localizedDescription)")
                }
            }
        }
    }
    
    public func startMonitoring() {
        DLOG("Start Monitoring \(watchedDirectory.path)")
        _stopMonitoring()
        
        let fd: Int32 = open(watchedDirectory.path, O_EVTONLY)
        
        if fd == 0 {
            ELOG("Unable open file system ref \(watchedDirectory)")
            assertionFailure("Unable open file system ref \(watchedDirectory)")
            return
        }
        
        // makeReadSource or makeWriteSource
        let dispatch_source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write], queue: serialQueue) // makeWriteSource(fileDescriptor: fd, queue: serialQueue)
        self.dispatch_source = dispatch_source
        
        dispatch_source.setRegistrationHandler {
            dispatch_source.setEventHandler(handler: {
                let contents = try? FileManager.default.contentsOfDirectory(at: self.watchedDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
                let previousContentsSet = Set(self.previousContents ?? [URL]())
                
                var contentsSet = Set(contents ?? [URL]())
                contentsSet.subtract(previousContentsSet)
                
                contentsSet = contentsSet.filter { url -> Bool in
                    // Ignore special files
                    url.lastPathComponent != "0"                     // ignore Temp file
                    && !url.lastPathComponent.starts(with: ".")     // ignore . hidden files
                    && !url.path.contains("_MACOSX")                 // ignore resource forks
                }
                
                contentsSet.forEach { file in
                    self.watchFile(at: file)
                }
                
                if let aContents = contents {
                    self.previousContents = aContents
                }
            })
            
            dispatch_source.setCancelHandler(handler: {
                close(fd)
            })
        }
        
        dispatch_source.resume()
        // trigger the event watcher above to start an initial import on launch
        let triggerPath = watchedDirectory.appendingPathComponent("0")
        
        do {
            try "0".write(to: triggerPath, atomically: false, encoding: .utf8)
            try FileManager.default.removeItem(atPath: triggerPath.path)
        } catch {
            ELOG("\(error.localizedDescription)")
        }
    }
    
    public func stopMonitoring() {
        DLOG("Stop Monitoring \(watchedDirectory.path)")
        _stopMonitoring()
    }
    
    private func _stopMonitoring() {
        if let dispatch_source = dispatch_source {
            dispatch_source.cancel()
            self.dispatch_source = nil
        }
    }
    
    public func watchFile(at path: URL) {
        DLOG("Start watching \(path.lastPathComponent)")
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: path.path)
            
            let filesize: UInt64 = attributes[FileAttributeKey.size] as? UInt64 ?? 0
            let immutable: Bool = attributes[FileAttributeKey.immutable] as? Bool ?? false
            VLOG("immutable \(immutable)")
            
            DispatchQueue.main.async { [weak self] () in
                if let weakSelf = self {
                    Timer.scheduledTimer(timeInterval: 2.0,
                                         target: weakSelf,
                                         selector: #selector(DirectoryWatcher.checkFileProgress(_:)),
                                         userInfo: ["path": path, "filesize": filesize, "wasZeroBefore": false] as [String:Any],
                                         repeats: false)
                }
            }
        } catch {
            ELOG("Error getting file attributes for \(path.path)")
            return
        }
    }
    
    @objc
    func checkFileProgress(_ timer: Timer) {
        guard
            let userInfo = timer.userInfo as? [String: Any],
            let path = userInfo["path"] as? URL,
            let previousFilesize = userInfo["filesize"] as? UInt64 else {
            ELOG("Timer missing userInfo or elements of it.")
            return
        }
        
        let exists = FileManager.default.fileExists(atPath: path.path)
        guard exists else { return }
        
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
        
        if sizeHasntChanged, currentFilesize > 0 || wasZeroBefore {
            let compressedExtensions = Extensions.archiveExtensions
            let ext = path.pathExtension
            
            if compressedExtensions.contains(ext) {
                serialQueue.async {
                    Task {
                        await self.extractArchive(at: path)
                    }
                }
            } else {
                if extractionCompleteHandler != nil {
                    DirectoryWatcher.handlerQueue.async { () in
                        self.extractionCompleteHandler?([path])
                    }
                }
            }
            return
        }
        let newUserInfo: [String:Any] = [
            "path": path,
            "filesize": currentFilesize,
            "wasZeroBefore": currentFilesize == 0
        ]
        Timer.scheduledTimer(timeInterval: 2.0,
                             target: self,
                             selector: #selector(DirectoryWatcher.checkFileProgress(_:)),
                             userInfo: newUserInfo,
                             repeats: false)
    }
    
    static var handlerQueue: DispatchQueue {
        // DispatchQueue.global(qos: .background)
        DispatchQueue.main
    }
    
    public func extractArchive(at filePath: URL) async {
        if filePath.path.contains("MACOSX") {
            return
        }
        
        DirectoryWatcher.handlerQueue.async { [weak self] () in
            self?.extractionStartedHandler?(filePath)
        }
        
        if !FileManager.default.fileExists(atPath: filePath.path) {
            WLOG("No file at \(filePath.path)")
            return
        }
        
        let watchedDirectory = self.watchedDirectory
        // watchedDirectory will be nil when we call stop
        stopMonitoring()
        
        let ext = filePath.pathExtension.lowercased()
        
        if ext == "zip" {
            Task {
                SSZipArchive.unzipFile(
                    atPath: filePath.path,
                    toDestination: watchedDirectory.path,
                    overwrite: true,
                    password: nil,
                    progressHandler: { (entry: String, _: unz_file_info, entryNumber: Int, total: Int) in
                        if !entry.isEmpty {
                            let url = watchedDirectory.appendingPathComponent(entry)
                            self.unzippedFiles.append(url)
                        }
                        
                        if self.extractionUpdatedHandler != nil {
                            DirectoryWatcher.handlerQueue.async { [weak self] in
                                self?.extractionUpdatedHandler?(filePath, entryNumber, total, Float(total) / Float(entryNumber))
                            }
                        }
                    }, completionHandler: { [weak self] (_: String?, succeeded: Bool, error: Error?) in
                        guard let self = self else { ELOG("nil self"); return }
                        if succeeded {
                            if self.extractionCompleteHandler != nil {
                                let unzippedItems = self.unzippedFiles
                                DirectoryWatcher.handlerQueue.async {
                                    self.extractionCompleteHandler?(unzippedItems)
                                }
                            }
                            do {
                                try FileManager.default.removeItem(atPath: filePath.path)
                            } catch {
                                ELOG("Unable to delete file at path \(filePath), because \(error.localizedDescription)")
                            }
                        } else if let error = error {
                            ELOG("Unable to unzip file: \(filePath) because: \(error.localizedDescription)")
                            DirectoryWatcher.handlerQueue.async { () in
                                self.extractionCompleteHandler?(nil)
                                NotificationCenter.default.post(name: NSNotification.Name.PVArchiveInflationFailed, object: self)
                            }
                        }
                        self.unzippedFiles.removeAll()
                        self.delayedStartMonitoring()
                    })
            }
        } else if ext == "7z" {
            Task {
                do {
                    let container = try Data(contentsOf: filePath)
                    let entries: [SevenZipEntry] = try SevenZipContainer.open(container: container)
                    
                    await entries.asyncForEach { item in
                        if item.info.type != .directory {
                            let fileName = item.info.name
                            // if needs this item - store to array.
                            let fullPath = watchedDirectory.appendingPathComponent(fileName)
                            self.unzippedFiles.append(fullPath)
                        }
                    }
                    
    #warning("TODO: Support natively using 7zips by matching crcs using PVLookup")
                    //                let crcs = Set(entries.filter {
                    //                    guard let crc = $0.info.crc, crc != 0 else { return false }
                    //                    return true
                    //                }.map { String($0.info.crc ?? 0, radix: 16, uppercase: true) })
                    //                if let releaseID = GameImporter.shared.releaseID(forCRCs: crcs) {
                    //                    ILOG("Found a release ID \(releaseID) inside this 7Zip")
                    //                }
                    
                    stopMonitoring()
                    let length = entries.count
                    try await entries.enumerated().asyncForEach { index, entry in
                        guard let data = entry.data else {
                            ELOG("7zip entry \(entry.info.name) data is nil.")
                            return
                        }
                        try data.write(to: watchedDirectory.standardizedFileURL, options: [.atomic, .noFileProtection])
                        
                        // Send update info
                        if extractionUpdatedHandler != nil {
                            let progress = Float(index) / Float(length)
                            DirectoryWatcher.handlerQueue.async { [weak self] () in
                                self?.extractionUpdatedHandler?(filePath, index, Int(length), progress)
                            }
                        }
                    }
                    
                    try FileManager.default.removeItem(at: filePath)
                    let unzippedItems = unzippedFiles
                    DirectoryWatcher.handlerQueue.async { [weak self] () in
                        self?.extractionCompleteHandler?(unzippedItems)
                    }
                    unzippedFiles.removeAll()
                    delayedStartMonitoring()
                } catch {
                    ELOG("7z open error: \(error.localizedDescription)")
                    startMonitoring()
                    return
                }
            }
        } else {
            startMonitoring()
        }
    }
    
    // Delay start so we have a moment to move files and stuff
    fileprivate func delayedStartMonitoring() {
        Task {
            await delay(2) {
                self.startMonitoring()
            }
        }
    }
}

/// - Note:
///     Usage:
///     Task {
///         await repeatingTimer(interval: 5.0) {
///            print("This will print every 5 seconds")
///         }
///     }
///
///
/// - Parameters:
///   - interval: Delay in seconds
///   - operation: Block to be executed
func repeatingTimer(interval: TimeInterval, _ operation: @escaping () async -> Void) async {
    while true {
        await operation()
        try? await Task.sleep(for: .seconds(interval))
    }
}

/// TimerSequence
/// - Note:
///   ```swift
///   Task {
///     for await date in TimerSequence(interval: 5.0) {
///         print("Timer fired at: \(date)")
///         }
///     }
///    ```
struct TimerSequence: AsyncSequence {
    typealias Element = Date
    let interval: TimeInterval

    struct AsyncIterator: AsyncIteratorProtocol {
        let interval: TimeInterval

        mutating func next() async -> Date? {
            try? await Task.sleep(for: .seconds(interval))
            return Date()
        }
    }

    func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(interval: interval)
    }
}

/// Run a Task after a delay
/// - Note:
/// Task {
///    await delay(5) {
///        print("This prints after a 5-second delay")
///    }
/// }
///
/// - Parameters:
///   - duration: Delay in Seconds
///   - operation: Block to execute
func delay(_ duration: TimeInterval, operation: @escaping () async -> Void) async {
    try? await Task.sleep(for: .seconds(duration))
    await operation()
}
