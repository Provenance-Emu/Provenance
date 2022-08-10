//
//  Benefit.swift
//  AltStore
//
//  Created by Riley Testut on 8/21/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import Foundation

//public typealias ALTPatreonBenefitType = String
//public let ALTPatreonBenefitTypeBetaAccess: ALTPatreonBenefitType = "1186336"
//public let ALTPatreonBenefitTypeCredits: ALTPatreonBenefitType = "1186340"

public enum ALTPatreonBenefitType: String, Codable, Equatable {
    case betaAccess = "1186336"
    case credits = "1186340"
}

extension PatreonAPI
{
    struct BenefitResponse: Decodable
    {
        var id: String
    }
}

public struct Benefit: Hashable
{
    public var type: ALTPatreonBenefitType
    
    init(response: PatreonAPI.BenefitResponse)
    {
        self.type = ALTPatreonBenefitType(response.id)
    }
}
