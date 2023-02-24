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
}
