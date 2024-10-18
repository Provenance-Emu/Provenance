//
//  UpdatePatronsOperation.swift
//  AltStore
//
//  Created by Riley Testut on 4/11/22.
//  Copyright © 2022 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

private extension URL
{
    #if STAGING
    static let patreonInfo = Const.staging.patreonInfo
    #else
    static let patreonInfo = Const.patreonInfo
    #endif
}

extension UpdatePatronsActor
{
    private struct Response: Decodable
    {
        var version: Int
        var accessToken: String
        var refreshID: String
    }
}

// An actor for dealing with Patreon API
actor UpdatePatronsActor {    
    func updatePatrons() async throws {
        do {
            let (data, response) = try await URLSession.shared.data(from: .patreonInfo)
            
            if let httpResponse = response as? HTTPURLResponse {
                guard httpResponse.statusCode != 404 else {
                    throw URLError(.fileDoesNotExist, userInfo: [NSURLErrorKey: URL.patreonInfo])
                }
            }
            
            let decodedResponse = try Foundation.JSONDecoder().decode(Response.self, from: data)
            Keychain.shared.patreonCreatorAccessToken = decodedResponse.accessToken
            
            let previousRefreshID = UserDefaults.shared.patronsRefreshID
            guard decodedResponse.refreshID != previousRefreshID else {
                return
            }
            
            let patrons = try await PatreonAPI.shared.fetchPatrons()
            
            try await Task {
                let managedPatrons = patrons.map { ManagedPatron(patron: $0) }
                
                let patronIDs = Set(managedPatrons.map { $0.identifier })
                let nonFriendZonePredicate = NSPredicate(format: "NOT (%K IN %@)", #keyPath(ManagedPatron.identifier), patronIDs)
                
                let nonFriendZonePatrons = ManagedPatron.all(satisfying: nonFriendZonePredicate, in: self.context)
                for managedPatron in nonFriendZonePatrons {
                    self.context.delete(managedPatron)
                }
                
                try self.context.save()
                
                UserDefaults.shared.patronsRefreshID = decodedResponse.refreshID
                
                print("Updated Friend Zone Patrons!")
            }
        } catch {
            throw error
        }
    }
}
