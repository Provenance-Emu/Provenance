//
//  Patron.swift
//  AltStore
//
//  Created by Riley Testut on 8/21/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import Foundation

extension PatreonAPI {
    struct PatronResponse: Codable, Equatable, Hashable {
        struct Attributes: Codable, Equatable, Hashable {
            var full_name: String
            var patron_status: String?
        }
        
        struct Relationships: Codable, Equatable, Hashable {
            struct Tiers: Codable, Equatable, Hashable {
                struct TierID: Codable, Equatable, Hashable {
                    var id: String
                    var type: String
                }
                
                var data: [TierID]
            }
            
            var currently_entitled_tiers: Tiers
        }
        
        var id: String
        var attributes: Attributes
        
        var relationships: Relationships?
    }
}

extension Patron {
    public enum Status: String, Codable, CaseIterable {
        case active = "active_patron"
        case declined = "declined_patron"
        case former = "former_patron"
        case unknown = "unknown"
    }
}

public class Patron: Identifiable, Codable, Equatable {
    public var name: String
    public var identifier: String
    
    public var status: Status
    
    public var benefits: Set<Benefit> = []
    
    init(response: PatreonAPI.PatronResponse) {
        self.name = response.attributes.full_name
        self.identifier = response.id
        
        if let status = response.attributes.patron_status {
            self.status = Status(rawValue: status) ?? .unknown
        } else {
            self.status = .unknown
        }
    }
}
