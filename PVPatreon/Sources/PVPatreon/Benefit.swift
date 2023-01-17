//
//  Benefit.swift
//  AltStore
//
//  Created by Riley Testut on 8/21/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import Foundation

public enum PVPatreonBenefitType: String {
	case betaAccess = "7585304"
	case credit = "8490206"
}

@available(iOS 12.0, tvOS 12.0, *)
extension PatreonAPI
{
    struct BenefitResponse: Decodable
    {
        var id: String
    }
}

@available(iOS 12.0, tvOS 12.0, *)
public struct Benefit: Hashable
{
    public var type: PVPatreonBenefitType
    
    init?(response: PatreonAPI.BenefitResponse)
    {
		guard let type = PVPatreonBenefitType(rawValue: response.id) else {
			ELOG("Unknown benefit id \(response.id)")
			return nil
		}
        self.type = type
    }
}
