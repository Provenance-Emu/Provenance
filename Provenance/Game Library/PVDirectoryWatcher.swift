//
//  PVDirectoryWatcher.swift
//  Provenance
//
//  Created by James Addyman on 11/04/2013.
//  Copyright (c) 2013 Testut Tech. All rights reserved.
//

import Foundation
import UIKit

public typealias PVExtractionStartedHandler = (_ path: URL) -> Void
public typealias PVExtractionUpdatedHandler = (_ path: URL, _ entryNumber: Int, _ total: Int, _ progress: Float) -> Void
public typealias PVExtractionCompleteHandler = (_ paths: [URL]?) -> Void

public extension NSNotification.Name {
    public static let PVArchiveInflationFailed = NSNotification.Name(rawValue: "PVArchiveInflationFailedNotification")
}

public class PVDirectoryWatcher: NSObject {

    private let watchedDirectory: URL

    private let extractionStartedHandler: PVExtractionStartedHandler?
    private let extractionUpdatedHandler: PVExtractionUpdatedHandler?
    private let extractionCompleteHandler: PVExtractionCompleteHandler?

    var dispatch_source: DispatchSourceFileSystemObject?
    let serialQueue: DispatchQueue = DispatchQueue(label: "com.provenance-emu.provenance.serialExtractorQueue")

    var previousContents: [URL]?
    private var reader: LzmaSDKObjCReader?
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

        super.init()

        serialQueue.async {
            do {
                let contents = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
                contents.forEach { file in
                    let exts = PVEmulatorConfiguration.archiveExtensions
                    let ext = file.pathExtension.lowercased()
                    if exts.contains(ext) {
                        self.extractArchive(at: file)
                    }
                }
            } catch {
                ELOG("\(error.localizedDescription)")
            }
        }
    }

    func startMonitoring() {
        DLOG("Start Monitoring \(watchedDirectory.path)")
        _stopMonitoring()

        let fd: Int32 = open(self.watchedDirectory.path, O_EVTONLY)

        if fd == 0 {
            ELOG("Unable open file system ref \(self.watchedDirectory)")
            assertionFailure("Unable open file system ref \(self.watchedDirectory)")
            return
        }

        // makeReadSource or makeWriteSource
        let dispatch_source =  DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write], queue: serialQueue) //makeWriteSource(fileDescriptor: fd, queue: serialQueue)
        self.dispatch_source = dispatch_source

        dispatch_source.setRegistrationHandler {
            dispatch_source.setEventHandler(handler: {
                let contents = try? FileManager.default.contentsOfDirectory(at: self.watchedDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
                let previousContentsSet = Set(self.previousContents ?? [URL]())

                var contentsSet = Set(contents ?? [URL]())
                contentsSet.subtract(previousContentsSet)

                contentsSet = contentsSet.filter({ (url) -> Bool in
                    // Ignore special files
                    return url.lastPathComponent != "0" && !url.lastPathComponent.starts(with: ".") && !url.path.contains("_MACOSX")
                })

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
        let triggerPath = self.watchedDirectory.appendingPathComponent("0")

        do {
            try "0".write(to: triggerPath, atomically: false, encoding: .utf8)
            try FileManager.default.removeItem(atPath: triggerPath.path)
        } catch {
            ELOG("\(error.localizedDescription)")
        }
    }

    func stopMonitoring() {
        DLOG("Stop Monitoring \(watchedDirectory.path)")
        _stopMonitoring()
    }

    private func _stopMonitoring() {
        if let dispatch_source = self.dispatch_source {
            dispatch_source.cancel()
            self.dispatch_source = nil
        }
    }

    func watchFile(at path: URL) {

        DLOG("Start watching \(path.lastPathComponent)")

        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: path.path)

            let filesize: UInt64 = attributes[FileAttributeKey.size] as? UInt64 ?? 0
			let immutable: Bool = attributes[FileAttributeKey.immutable] as? Bool ?? false
			print("immutable \(immutable)")

            DispatchQueue.main.async {[weak self] () -> Void in
                if let weakSelf = self {
                    Timer.scheduledTimer(timeInterval: 2.0, target: weakSelf, selector: #selector(PVDirectoryWatcher.checkFileProgress(_:)), userInfo: ["path": path, "filesize": filesize, "wasZeroBefore": false], repeats: false)
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

        if sizeHasntChanged && (currentFilesize > 0 || wasZeroBefore) {
            let compressedExtensions = PVEmulatorConfiguration.archiveExtensions
            let ext = path.pathExtension

            if compressedExtensions.contains(ext) {
                serialQueue.async {
                    self.extractArchive(at: path)
                }
            } else {
                if extractionCompleteHandler != nil {
                    DispatchQueue.main.async(execute: {() -> Void in
                        self.extractionCompleteHandler?([path])
                    })
                }
            }
            return
        }

        Timer.scheduledTimer(timeInterval: 2.0, target: self, selector: #selector(PVDirectoryWatcher.checkFileProgress(_:)), userInfo: ["path": path, "filesize": currentFilesize, "wasZeroBefore": (currentFilesize == 0)], repeats: false)
    }

    func extractArchive(at filePath: URL) {

        if filePath.path.contains("MACOSX") {
            return
        }

        DispatchQueue.main.async(execute: {() -> Void in
            self.extractionStartedHandler?(filePath)
        })

        if !FileManager.default.fileExists(atPath: filePath.path) {
            WLOG("No file at \(filePath.path)")
            return
        }

        let watchedDirectory = self.watchedDirectory
        // watchedDirectory will be nil when we call stop
        stopMonitoring()

        let ext = filePath.pathExtension.lowercased()

        if ext == "zip" {
            SSZipArchive.unzipFile(atPath: filePath.path, toDestination: watchedDirectory.path, overwrite: true, password: nil, progressHandler: { (entry : String?, zipInfo : unz_file_info, entryNumber : Int, total : Int, fileSize : UInt64, bytesRead : UInt64) in
                if let entry = entry, !entry.isEmpty {
                    let url = watchedDirectory.appendingPathComponent(entry)
                    self.unzippedFiles.append(url)
                }

                if self.extractionUpdatedHandler != nil {
                    DispatchQueue.main.async {
                        self.extractionUpdatedHandler?(filePath, entryNumber, total, Float(bytesRead) / Float(fileSize))
                    }
                }
            }, completionHandler: { (path: String?, succeeded: Bool, error: Error?) in
                if succeeded {
                    if self.extractionCompleteHandler != nil {
                        let unzippedItems = self.unzippedFiles
                        DispatchQueue.main.async {
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
                    DispatchQueue.main.async(execute: {() -> Void in
                        self.extractionCompleteHandler?(nil)
                        NotificationCenter.default.post(name: NSNotification.Name.PVArchiveInflationFailed, object: self)
                    })
                }
                self.unzippedFiles.removeAll()
                self.delayedStartMonitoring()
            })
        } else if ext == "7z" {
            let reader = LzmaSDKObjCReader(fileURL: filePath, andType: LzmaSDKObjCFileType7z)
            self.reader = reader
            reader.delegate = self

            do {
                try reader.open()
            } catch {
                ELOG("7z open error: \(error.localizedDescription)")
                startMonitoring()
                return
            }

            var items = [LzmaSDKObjCItem]()

            // Array with selected items.
            // Iterate all archive items, track what items do you need & hold them in array.
            reader.iterate(handler: { (item, error) -> Bool in
                if let error = error {
                    ELOG("7z error: \(error.localizedDescription)")
                    return true // Continue to iterate, false to stop
                }

                items.append(item)
                // if needs this item - store to array.
                if !item.isDirectory, let fileName = item.fileName {
                    let fullPath = watchedDirectory.appendingPathComponent(fileName)
                    self.unzippedFiles.append(fullPath)
                }

                return true // Continue to iterate
            })

			// TODO : Support natively using 7zips by matching crcs
			let crcs = Set(items.filter({ $0.crc32 != 0}).map { return String($0.crc32, radix: 16, uppercase: true) })
			if let releaseID = PVGameImporter.shared.releaseID(forCRCs: crcs) {
				ILOG("Found a release ID \(releaseID) inside this 7Zip")
			}

            stopMonitoring()
            reader.extract(items, toPath: watchedDirectory.path, withFullPaths: false)
        } else {
            self.startMonitoring()
        }
    }

    // Delay start so we have a moment to move files and stuff
    fileprivate func delayedStartMonitoring() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: {
            self.startMonitoring()
        })
    }
}
extension PVDirectoryWatcher: LzmaSDKObjCReaderDelegate {
    public func onLzmaSDKObjCReader(_ reader: LzmaSDKObjCReader, extractProgress progress: Float) {
        guard let fileURL = reader.fileURL else {
            ELOG("fileURL of reader was nil")
            return
        }

        if progress >= 1 {
            if extractionCompleteHandler != nil {
                let unzippedItems = unzippedFiles
                DispatchQueue.main.async(execute: {() -> Void in
                    self.extractionCompleteHandler?(unzippedItems)
                })
            }

            do {
                try FileManager.default.removeItem(at: fileURL)
            } catch {
                ELOG("Unable to delete file at path \(fileURL.path), because \(error.localizedDescription)")
            }

            unzippedFiles.removeAll()
            delayedStartMonitoring()
        } else {
            if extractionUpdatedHandler != nil {
                DispatchQueue.main.async(execute: {() -> Void in
                    let entryNumber = Int(floor(Float(reader.itemsCount) * progress))
                    self.extractionUpdatedHandler?(fileURL, entryNumber, Int(reader.itemsCount), progress)
                })
            }
        }
    }
}
