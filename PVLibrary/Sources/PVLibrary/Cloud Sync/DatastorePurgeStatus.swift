//
//  DatastorePurgeStatus.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/29/25.
//

/// used for only purging database entries that no longer exist (files deleted from icloud while the app was shut off)
public enum DatastorePurgeStatus {
    case incomplete
    case complete
}
