//
//  GameImporter2.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 12/26/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

import Foundation
import Promises
import RxSwift

public enum ImporterFileType {
    case rom
    case image
    case package(SerializerPackageType)
    case archive(ImporterArchiveType)
    case unknown
}

public enum ImporterArchiveType {
    case zip
    case gzip
    case sevenZip
    case rar

    var supportsCRCs: Bool { return true }
}

enum MatchHashType {
    case MD5
    case CRC
    case SHA1
}

enum MatchType {
    case byExtension
    case byHash(MatchHashType)
    case byFolder
    case manually
}

extension URL {
    var isFileArchive: Bool {
        guard isFileURL else { return false }
        let ext = pathExtension.lowercased()
        return PVEmulatorConfiguration.archiveExtensions.contains(ext)
    }
}

struct ImportCandiate2 {
    let url: URL

    var isFileArchive: Promise<Bool> { return Promise { self.url.isFileArchive } }
}

public final class ImporterService {
    public static let shared: ImporterService = ImporterService()

    private let dispaseBag = DisposeBag()
    private init() {
        DirectoryWatcher2.shared.newFile
            .do(onNext: handleNewFile(_:))
            .subscribe()
            .disposed(by: dispaseBag)
    }

    private func handleNewFile(_ url: URL) throws {
        let importCandidate = ImportCandiate2(url: url)
//
//        importCandidate.isFileArchive.then {
//            if $0 {
//
//            }
//        }
//
//        Promise.Async {
//            if url.isFileArchive {
//                return Promise()
//            } else {
//                GameImporter
//            }
//        }
    }

    /*
     Flow:

     File Scanning:
     1. Detect file

     1. Is file archive
     a. contains sub zips?
     a. Move to processing folder
     b. Does arvhcie support CRCs
     i. Does CRC match

     2. Is file single
     a. Is preseleted system
     match(filtered):
     i. match by MD5 / SHA1
     ii. match by extension
     z. single match, move system
     y. multi-match, move to conflicts

     */
}
