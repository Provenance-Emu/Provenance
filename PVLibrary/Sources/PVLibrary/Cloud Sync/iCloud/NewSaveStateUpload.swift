//
//  NewSaveStateUpload.swift
//  PVLibrary
//

import Foundation

/// What iCloud sync does with a save state that was just added to the library.
enum NewSaveStateUpload: Equatable {
    /// It came from iCloud, so it is already there.
    case ignore
    /// Sync frequency is Manual: it waits for the next Sync.
    case hold
    /// Put it on the upload queue now. The queue waits by itself while a game is running.
    case enqueue

    static func decide(hasCloudRecord: Bool, isManualCadence: Bool) -> NewSaveStateUpload {
        if hasCloudRecord { return .ignore }
        return isManualCadence ? .hold : .enqueue
    }
}
