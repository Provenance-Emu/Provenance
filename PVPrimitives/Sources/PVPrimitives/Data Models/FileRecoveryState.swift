//
//  FileRecoveryState.swift
//  PVPrimitives
//
//  Created by Joseph Mattiello on 4/26/25.
//


/// Represents the state of the file recovery process
public enum FileRecoveryState: Equatable {
    case idle
    case inProgress
    case complete
    case error
}

// MARK: - FileRecoveryState Extension (Example if needed)
public extension FileRecoveryState {
    public  var isRecovering: Bool { self == .inProgress }
    public var isFailed: Bool { self == .error }
    public var isIdle: Bool { self == .idle }
    public var isInProgress: Bool { self == .inProgress }
}
