//
//  Tier.swift
//  AltStore
//
//  Created by Riley Testut on 8/21/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import Foundation

public struct Tier: Identifiable, Codable, Equatable, Hashable {
    public var name: String
    public var identifier: String
    
    public var benefits: [Benefit] = []
    
    init(response: PatreonAPI.TierResponse) {
        self.name = response.attributes.title
        self.identifier = response.id
        self.benefits = response.relationships.benefits.data.compactMap(Benefit.init(response:))
    }
}

extension PatreonAPI {
    struct TierResponse: Codable, Equatable, Hashable {
        struct Attributes: Codable, Equatable, Hashable {
            var title: String
        }
        
        struct Relationships: Codable, Equatable, Hashable {
            struct Benefits: Codable, Equatable, Hashable {
                var data: [BenefitResponse]
            }
            
            var benefits: Benefits
        }
        
        var id: String
        var attributes: Attributes
        
        var relationships: Relationships
    }
}
