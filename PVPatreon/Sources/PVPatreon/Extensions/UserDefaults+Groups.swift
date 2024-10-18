//
//  UserDefaults+Groups.swift
//  PVPatreon
//
//  Created by Joseph Mattiello on 9/28/24.
//

import Foundation

package extension UserDefaults
{
    static let shared: UserDefaults = {
        guard let appGroup = Bundle.main.appGroups.first else { return .standard }
        
        let sharedUserDefaults = UserDefaults(suiteName: appGroup)!
        return sharedUserDefaults
    }()
}
