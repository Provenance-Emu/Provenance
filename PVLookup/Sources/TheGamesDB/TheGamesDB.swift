//
//  Service_TheGamesDB.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 12/30/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation
import PVLogging

#if canImport(OpenAPIRuntime)

import OpenAPIRuntime
import OpenAPIURLSession
// Swagger documention at
// https://api.thegamesdb.net/

let API_KEY = "fe49d95136b2d03e2ae86dead3650af597928885fe4aa573d9dba805d66027a7"

/// An interface to `https://api.thegamesdb.net/`
/// aka The Games DB
public struct TheGamesDBService {
    
    public init() {}
    
    public enum TheGamesDBServiceError: Error {
        case notFound, badRequest, forbidden, unknown
    }
    
    /// Local client
    let client = Client(
        serverURL: try! Servers.server1(),
        transport: URLSessionTransport()
    )
    
    /// Get a single game by ID async
    /// - Parameter id: ID of the game
    /// - Returns: Dictionary of JSON or throws
    func getGame(id: String, includeBoxArt: Bool = true, page: Int? = nil) async throws -> Components.Schemas.Game? {
   
        // Create request and await response
        let response = try await client.GamesByGameID(query: .init(
            apikey: API_KEY,
            id: id,
            include: includeBoxArt ? "boxart" : nil,
            page: page))
        
        switch response {
        case .ok(let okResponse):
            switch okResponse.body {
            case .json(let games):
//                let currentPage = games.value1.value2.pages.current
//                let nextPage = games.value1.value2.pages.next
//                print(games.value1)
//                print(games.value2)
                return games.value2.data.games.first
            }
        case .undocumented(statusCode: let statusCode, _):
            ELOG("🤨 undocumented response: \(statusCode)")
            throw TheGamesDBServiceError.unknown
        case .badRequest(let response):
            ELOG("😷 badRequest response: \(response)")
            throw TheGamesDBServiceError.badRequest
        case .forbidden(let response):
            ELOG("🚫 forbidden response: \(response)")
            throw TheGamesDBServiceError.forbidden
        }
    }
    
    func getGames(serials: [String], page: Int? = nil) async throws -> [Components.Schemas.Game] {
        
        // Generate the url to get games by unique id
        // Append the serials to the url as a comma separated list

        let response = try await client.GamesByGameID(query: .init(
            apikey: API_KEY,
            id: serials.joined(separator: ","),
            page: page))
        
        switch response {
        case .ok(let okResponse):
            switch okResponse.body {
            case .json(let games):
                let currentPage = games.value1.value2.pages.current
                let nextPage = games.value1.value2.pages.next
                
                if nextPage > currentPage {
                    let nextPageData =  try await getGames(serials: serials, page: Int(nextPage))
                    return games.value2.data.games + nextPageData
                } else {
                    return games.value2.data.games
                }
            }
        case .undocumented(statusCode: let statusCode, _):
            ELOG("🤨 undocumented response: \(statusCode)")
            throw TheGamesDBServiceError.unknown
        case .badRequest(let response):
            ELOG("😷 badRequest response: \(response)")
            throw TheGamesDBServiceError.badRequest
        case .forbidden(let response):
            ELOG("🚫 forbidden response: \(response)")
            throw TheGamesDBServiceError.forbidden
        }
    }
    
    func getGamesList(platformID: String, page: Int? = nil) async throws -> [Components.Schemas.Game] {
        
        let response = try await client.GamesByPlatformID(query: .init(
            apikey: API_KEY,
            id: platformID,
            page: page))
        
        switch response {
        case .ok(let okResponse):
            switch okResponse.body {
            case .json(let games):
                let currentPage = games.value1.value2.pages.current
                let nextPage = games.value1.value2.pages.next
                
                if nextPage > currentPage {
                    let nextPageData =  try await getGamesList(platformID: platformID, page: Int(nextPage))
                    return games.value2.data.games + nextPageData
                } else {
                    return games.value2.data.games
                }
            }
        case .undocumented(statusCode: let statusCode, _):
            ELOG("🤨 undocumented response: \(statusCode)")
            throw TheGamesDBServiceError.unknown
        case .badRequest(let response):
            ELOG("😷 badRequest response: \(response)")
            throw TheGamesDBServiceError.badRequest
        case .forbidden(let response):
            ELOG("🚫 forbidden response: \(response)")
            throw TheGamesDBServiceError.forbidden
        }
    }
}
#endif

// MARK: - Shorthand funcs

//extension TheGamesDBService {
//    func game(id: String) async throws -> [String: Any] { try await getGame(id: id) }
//
//    func games(serials: [String]) async throws -> [String: Any] { try await getGames(serials: serials) }
//    func games(platformID: String) async throws -> [String: Any] { try await getGamesList(id: id) }
//}
//// MARK: - Primitive type funcs
//extension TheGamesDBService {
//    func getGame(id: Int) -> Game {
//        return get(endpoint: .game(id: id)).wait()
//    }
//}
//
//// MARK: - Combine
//import Combine
//extension TheGamesDBService {
//    func getGame(id: Int) -> Future<Game, Error> {
//        return get(endpoint: .game(id: id))
//    }
//}
