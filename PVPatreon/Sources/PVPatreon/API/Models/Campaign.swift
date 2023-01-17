//
//  Campaign.swift
//  AltStore
//
//  Created by Riley Testut on 8/21/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import Foundation

public struct Campaign: Codable, Equatable, Hashable {
    public var identifier: String
        
    init(response: PatreonAPI.CampaignResponse) {
        self.identifier = response.id
    }
}

extension PatreonAPI {
    struct CampaignResponse: Codable, Equatable, Hashable {
        var id: String
    }
}
