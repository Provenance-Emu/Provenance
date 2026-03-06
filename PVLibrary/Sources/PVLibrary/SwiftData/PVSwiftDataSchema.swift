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
/// All @Model types must be listed here. The container is configured via
/// `makePVModelContainer`.
@available(iOS 17.0, tvOS 17.0, macOS 14.0, watchOS 10.0, visionOS 1.0, *)
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

    /// Creates and returns the shared `ModelContainer` for the Provenance library.
    ///
    /// - Parameter inMemory: When `true` the container uses an in-memory store
    ///   (useful for previews and unit tests).
    public static func makePVModelContainer(inMemory: Bool = false) throws -> ModelContainer {
        let config = ModelConfiguration(
            schema: v1Schema,
            isStoredInMemoryOnly: inMemory
        )
        return try ModelContainer(configurations: config)
    }

    /// Delete all objects for every tracked model type from the given context and save.
    ///
    /// Centralised here so that `SwiftDataDatabaseDriver` and `SwiftDataDatabaseActor`
    /// share a single authoritative list, preventing drift as the schema evolves.
    public static func deleteAll(from context: ModelContext) throws {
        try context.delete(model: Game_Data.self)
        try context.delete(model: System_Data.self)
        try context.delete(model: SaveState_Data.self)
        try context.delete(model: RecentGame_Data.self)
        try context.delete(model: Core_Data.self)
        try context.delete(model: BIOS_Data.self)
        try context.delete(model: Cheats_Data.self)
        try context.delete(model: File_Data.self)
        try context.delete(model: ImageFile_Data.self)
        try context.delete(model: Library_Data.self)
        try context.delete(model: User_Data.self)
        try context.save()
    }
}
#endif
