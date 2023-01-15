//
//  Campaign.swift
//  AltStore
//
//  Created by Riley Testut on 8/21/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import Foundation

@available(iOS 12.0, tvOS 12.0, *)
extension PatreonAPI
{
    struct CampaignResponse: Decodable
    {
        var id: String
    }
}

@available(iOS 12.0, tvOS 12.0, *)
public struct Campaign
{
    public var identifier: String
        
    init(response: PatreonAPI.CampaignResponse)
    {
        self.identifier = response.id
    }
}
