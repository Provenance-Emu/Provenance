//
//  iCloudSaveStateSyncer.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/29/25.
//

import Foundation
import Combine
import PVPrimitives

class iCloudSaveStateSyncer: iCloudContainerSyncer {
    let jsonDecorder = JSONDecoder()
    let processed = ConcurrentSingle<Int>(0)
    let processingState: ConcurrentSingle<ProcessingState> = .init(.idle)
    var savesDatabaseSubscriber: AnyCancellable?
    //initially when downloading, we need to keep a local cache of what has been processed. for large libraries we are pausing/stopping/starting query after an event processed. so when this happens, the saves are inserted several times and 2000 files, from the test where this happened, turned into 10k files and the app got a lot of app hangs.
    lazy var initiallyProcessedFiles: ConcurrentSet<URL> = []

    convenience init(notificationCenter: NotificationCenter = .default, errorHandler: SyncErrorHandler) {
        self.init(directories: ["Save States"], notificationCenter: notificationCenter, errorHandler: errorHandler)
        fileImportQueueMaxCount = 1
        jsonDecorder.dataDecodingStrategy = .deferredToData

        let publishers = [
            .SavesFinishedImporting,
            .RomDatabaseInitialized]
            .map { notificationCenter.publisher(for: $0) }
        savesDatabaseSubscriber = Publishers.MergeMany(publishers).sink { [weak self] _ in
            Task {
                await self?.importNewSaves()
            }
        }
    }

    override func stopObserving() {
        super.stopObserving()
        savesDatabaseSubscriber?.cancel()
    }

    override func setNewCloudFilesAvailable() async {
        await super.setNewCloudFilesAvailable()
        guard await status.value == .filesAlreadyMoved
        else {
            return
        }
        await initiallyProcessedFiles.removeAll()
    }

    func removeSavesDeletedWhileApplicationClosed() async {
        await removeDeletionsCriticalSection.performWithLock { [weak self] in
            guard let canPurge = await self?.canPurgeDatastore,
                  canPurge
            else {
                return
            }
            defer {
                self?.purgeStatus = .complete
            }
            do {
                let romsDatastore: RomsDatastore = try await .init()
                try await romsDatastore.deleteSaveStatesRemoveWhileApplicationClosed()
            } catch {
                ELOG("error clearing saves deleted while application was closed")
            }
        }
    }

    override func insertDownloadedFile(_ file: URL) async {
        guard let _ = await pendingFilesToDownload.remove(file),
              await !initiallyProcessedFiles.contains(file),
              "json".caseInsensitiveCompare(file.pathExtension) == .orderedSame
        else {
            return
        }
        ILOG("downloaded save file: \(file)")
        await newFiles.insert(file)
        await importNewSaves()
    }

    override func deleteFromDatastore(_ file: URL) async {
        guard "jpg".caseInsensitiveCompare(file.pathExtension) == .orderedSame
        else {
            return
        }
        do {
            let romsDatastore: RomsDatastore = try await .init()
            try await romsDatastore.deleteSaveState(file: file)
        } catch {
            await errorHandler.handleError(error, file: file)
            ELOG("error deleting \(file) from database: \(error)")
        }
    }

    func getSaveFrom(_ json: URL) throws -> SaveState? {
        guard fileManager.fileExists(atPath: json.pathDecoded)
        else {
            return nil
        }
        let secureDoc = json.startAccessingSecurityScopedResource()

        defer {
            if secureDoc {
                json.stopAccessingSecurityScopedResource()
            }
        }

        var dataMaybe = fileManager.contents(atPath: json.pathDecoded)
        if dataMaybe == nil {
            dataMaybe = try Data(contentsOf: json, options: [.uncached])
        }
        guard let data = dataMaybe else {
            throw iCloudError.dataReadFail
        }

        DLOG("Data read \(String(describing: String(data: data, encoding: .utf8)))")
        let save: SaveState
        do {
            save = try jsonDecorder.decode(SaveState.self, from: data)
        } catch {
            save = try jsonDecorder.decode(SaveState.self, from: try getUpdatedSaveState2(from: data, json: json))
        }
        DLOG("Read JSON data at (\(json.pathDecoded)")
        return save
    }

    /// Attempts to fix/migrate a SaveState from 2.x to 3.x
    /// - Parameters:
    ///   - fileContents: binary of json save state
    ///   - json: URL of save state
    /// - Returns: new binary if succeeds or nil if there is any error
    func getUpdatedSaveState2(from fileContents: Data, json: URL) throws -> Data {
        guard var stringContents = String(data: fileContents, encoding: .utf8)
        else {
            ELOG("error converting \(json) to a string")
            throw SaveStateUpdateError.failedToConvertToString
        }
        if let firstCurlyBrace = stringContents.range(of: "{") {
            stringContents.insert(contentsOf: "\"isPinned\":false,\"isFavorite\":false,", at: firstCurlyBrace.upperBound)
        } else {
            ELOG("error \(json) does NOT contain an opening curly brace {")
            throw SaveStateUpdateError.missingOpeningCurlyBrace
        }
        if let range = stringContents.range(of: "\"core\":{") {
            stringContents.insert(contentsOf: "\"systems\":[],", at: range.upperBound)
        } else {
            ELOG("error \(json) does NOT contain a 'core' field")
            throw SaveStateUpdateError.missingCoreKey
        }
        guard let updated = stringContents.data(using: .utf8)
        else {
            throw SaveStateUpdateError.errorConvertingStringToBinary
        }
        return updated
    }

    func importNewSaves() async {
        guard RomDatabase.databaseInitialized
        else {
            return
        }
        await removeSavesDeletedWhileApplicationClosed()
        guard await !newFiles.isEmpty,
              await processingState.value == .idle
        else {
            return
        }
        let jsonFiles = await prepareNextBatchToProcess()
        guard !jsonFiles.isEmpty
        else {
            return
        }
        //process save files batch
        await processJsonFiles(jsonFiles)
    }

    func processJsonFiles(_ jsonFiles: any Collection<URL>) async {
        //setup processed count
        await processingState.set(value: .processing)
        var processedCount = await processed.value
        let pendingFilesToDownloadCount = await pendingFilesToDownload.count
        ILOG("Saves: downloading: \(pendingFilesToDownloadCount), processing: \(jsonFiles.count), total processed: \(processedCount)")
        for json in jsonFiles {
            do {
                await processed.set(value: await processed.value + 1)
                processedCount = await processed.value
                guard let save: SaveState = try getSaveFrom(json)
                else {
                    continue
                }
                let romsDatastore = try await RomsDatastore()
                guard let existing: PVSaveState = await romsDatastore.findSaveState(forPrimaryKey: save.id)
                else {
                    ILOG("Saves: processing: save #(\(processedCount)) \(json)")
                    await storeNewSave(save, romsDatastore, json)
                    continue
                }
                await updateExistingSave(existing, romsDatastore, save, json, processedCount)

            } catch {
                await errorHandler.handleError(error, file: json)
                ELOG("Decode error on \(json): \(error)")
            }
        }
        //update processed count
        await processingState.set(value: .idle)
        await removeSavesDeletedWhileApplicationClosed()
        notificationCenter.post(Notification(name: .SavesFinishedImporting))
    }

    func updateExistingSave(_ existing: PVSaveState, _ romsDatastore: RomsDatastore, _ save: SaveState, _ json: URL, _ processedCount: Int) async {
        guard let game = await romsDatastore.findGame(md5: save.game.md5Hash, forSave: existing)
        else {
            return
        }
        ILOG("Saves: updating: save #(\(processedCount)) \(json)")
        do {
            try await romsDatastore.update(existingSave: existing, with: game)
        } catch {
            await errorHandler.handleError(error, file: json)
            ELOG("Failed to update game \(json): \(error)")
        }
    }

    func storeNewSave(_ save: SaveState, _ romsDatastore: RomsDatastore, _ json: URL) async {
        do {
            try await romsDatastore.create(newSave: save)
            if await status.value == .initialUpload {
                await initiallyProcessedFiles.insert(json)
            }
        } catch {
            await errorHandler.handleError(error, file: json)
            ELOG("error adding new save \(json): \(error)")
        }
        ILOG("Added new save \(json)")
    }
}
