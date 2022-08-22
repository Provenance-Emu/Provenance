//
//  DirectoryWatcher+Decrompession.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 8/19/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation
import Foundation
@_exported import PVSupport
import ZipArchive
import SWCompression

public extension DirectoryWatcher {
	func extractArchive(at filePath: URL) {
		if filePath.path.contains("MACOSX") {
			return
		}

		DispatchQueue.main.async(execute: { [weak self]() -> Void in
			self?.extractionStartedHandler?(filePath)
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
			

			SSZipArchive.unzipFile(atPath: filePath.path, toDestination: watchedDirectory.path, overwrite: true, password: nil, progressHandler: { (entry: String, _: unz_file_info, entryNumber: Int, total: Int) in
				if !entry.isEmpty {
					let url = watchedDirectory.appendingPathComponent(entry)
					self.unzippedFiles.append(url)
				}

				if self.extractionUpdatedHandler != nil {
					DispatchQueue.main.async { [weak self] in
						self?.extractionUpdatedHandler?(filePath, entryNumber, total, Float(total) / Float(entryNumber))
					}
				}
			}, completionHandler: { [weak self] (_: String?, succeeded: Bool, error: Error?) in
				guard let self = self else { ELOG("nil self"); return }
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
					DispatchQueue.main.async(execute: { () -> Void in
						self.extractionCompleteHandler?(nil)
						NotificationCenter.default.post(name: NSNotification.Name.PVArchiveInflationFailed, object: self)
					})
				}
				self.unzippedFiles.removeAll()
				self.delayedStartMonitoring()
			})

		} else if ext == "7z" {

			do {
				var entries = try SevenZipContainer.open(container: testData)
				var items = [LzmaSDKObjCItem]()

			}



			// Array with selected items.
			// Iterate all archive items, track what items do you need & hold them in array.
			reader.iterate(handler: {[weak self] (item, error) -> Bool in
				guard let self = self else { ELOG("nil self"); return false}
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

			// TODO: Support natively using 7zips by matching crcs
			let crcs = Set(items.filter({ $0.crc32 != 0 }).map { String($0.crc32, radix: 16, uppercase: true) })
			if let releaseID = GameImporter.shared.releaseID(forCRCs: crcs) {
				ILOG("Found a release ID \(releaseID) inside this 7Zip")
			}

			stopMonitoring()
			reader.extract(items, toPath: watchedDirectory.path, withFullPaths: false)
		} else {
			startMonitoring()
		}
	}
}
