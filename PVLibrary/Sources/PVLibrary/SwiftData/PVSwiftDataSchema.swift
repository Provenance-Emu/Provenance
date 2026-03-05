//
//  PVSwiftDataSchema.swift
//  PVLibrary
//
//  Created by Agent on 2025-03-05.
//
//  Defines the SwiftData ModelContainer schema and versioned migration plan
//  for the Provenance game library.
//

#if canImport(SwiftData)
import SwiftData

/// The full schema for Provenance's SwiftData store — version 1.
///
/// All @Model types must be listed here. The container is configured in
/// `PVSwiftDataContainer`.
public enum PVSwiftDataSchema {
    /// Schema v1: initial SwiftData migration from Realm.
    public static let v1Schema = Schema([
        Game_Data.self,
        System_Data.self,
        SaveState_Data.self,
        Core_Data.self,
        BIOS_Data.self,
        Cheats_Data.self,
        File_Data.self,
        ImageFile_Data.self,
        Library_Data.self,
        RecentGame_Data.self,
        User_Data.self,
    ])
}

/// Creates and returns the shared `ModelContainer` for the Provenance library.
///
/// - Parameter inMemory: When `true` the container uses an in-memory store
///   (useful for previews and unit tests).
public func makePVModelContainer(inMemory: Bool = false) throws -> ModelContainer {
    let config = ModelConfiguration(
        schema: PVSwiftDataSchema.v1Schema,
        isStoredInMemoryOnly: inMemory
    )
    return try ModelContainer(
        for: PVSwiftDataSchema.v1Schema,
        configurations: config
    )
}
#endif
