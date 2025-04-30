//
//  iCloudTypeSyncer.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/29/25.
//

import Foundation
import RxSwift

public protocol iCloudTypeSyncer: Container, SyncProvider {
    var metadataQuery: NSMetadataQuery { get }
    var downloadedCount: Int { get async }
    
    func loadAllFromICloud(iterationComplete: (() async -> Void)?) async -> Completable
    func insertDownloadingFile(_ file: URL) async -> URL?
    func insertDownloadedFile(_ file: URL) async
    func insertUploadedFile(_ file: URL) async
    func deleteFromDatastore(_ file: URL) async
    func setNewCloudFilesAvailable() async
}
