//
//  Cheats.swift
//  PVLibrary
//

import Foundation

public protocol CheatsInfoProvider {
    var id: String { get }
    var game: Game { get }
    var core: Core { get }
    var code: String { get }
    var type: String { get }
    var date: Date { get }
    var lastOpened: Date? { get }
    var enabled: Bool { get }
    var file: FileInfo { get }
}

public struct Cheats: CheatsInfoProvider, Codable {
    public let id: String
    public let game: Game
    public let core: Core
    public let code: String
    public let type: String
    public let date: Date
    public let lastOpened: Date?
    public let enabled: Bool
    public let file: FileInfo
    
    public init(id: String, game: Game, core: Core, code: String, type: String, date: Date, lastOpened: Date?, enabled: Bool, file: FileInfo) {
        self.id = id
        self.game = game
        self.core = core
        self.code = code
        self.type = type
        self.date = date
        self.lastOpened = lastOpened
        self.enabled = enabled
        self.file = file
    }
}

// MARK: - Equatable
extension Cheats: Equatable {
    public static func == (lhs: Cheats, rhs: Cheats) -> Bool {
        return lhs.id == rhs.id
    }
}

#if canImport(CoreTransferable)
import CoreTransferable
import UniformTypeIdentifiers
@available(iOS 16.0, macOS 13, *)
extension Cheats: Transferable {
    public static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .cheat)
    }
}
#endif
