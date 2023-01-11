//
//  PatreonAccount.swift
//  AltStore
//
//  Created by Riley Testut on 8/20/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import CoreData

extension PatreonAPI {
    struct AccountResponse: Codable, Equatable, Hashable {
        static func == (lhs: PatreonAPI.AccountResponse, rhs: PatreonAPI.AccountResponse) -> Bool {
            return lhs.data.id == rhs.data.id
        }
        
        struct Data: Codable, Equatable, Hashable {
            struct Attributes:  Codable, Equatable, Hashable {
                var first_name: String?
                var full_name: String
            }
            
            var id: String
            var attributes: Attributes
        }
        
        var data: Data
        var included: [PatronResponse]?
    }
}


public struct PatreonAccount: Identifiable, Codable, Equatable, Hashable {
    public let identifier: String
    
	public let name: String
	public let firstName: String?
    
	public let isPatron: Bool
    
    init(response: PatreonAPI.AccountResponse) {
        self.identifier = response.data.id
        self.name = response.data.attributes.full_name
        self.firstName = response.data.attributes.first_name
        
        if let patronResponse = response.included?.first {
            let patron = Patron(response: patronResponse)
            self.isPatron = (patron.status == .active)
        } else {
            self.isPatron = false
        }
    }
}
