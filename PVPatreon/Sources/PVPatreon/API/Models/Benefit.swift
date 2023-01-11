//
//  Benefit.swift
//  AltStore
//
//  Created by Riley Testut on 8/21/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import Foundation
import PVLogging

public enum PVPatreonBenefitType: String, Codable, Equatable, CaseIterable, Hashable {
	case betaAccess = "7585304"
	case credits = "8490206"
    case cloudSaves = "12039757"
    case cloudROMs = "12218444"
    case cloudISOs = "12423258"
}

extension PatreonAPI {
    struct BenefitResponse: Codable, Equatable, Hashable {
        var id: String
    }
}

public struct Benefit: Codable, Equatable, Hashable {
    public var type: PVPatreonBenefitType
    
    init?(response: PatreonAPI.BenefitResponse) {
		guard let type = PVPatreonBenefitType(rawValue: response.id) else {
            ELOG("ERROR: Unknown benefit id \(response.id)")
			return nil
		}
        self.type = type
    }
}
