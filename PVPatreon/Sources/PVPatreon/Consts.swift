//
//  Consts.swift
//  PVPatreon
//
//  Created by Joseph Mattiello on 12/17/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation

package class PVPatreonHandle: NSObject { }
package enum Const {
    static let bundle: Bundle = Bundle(for: PVPatreonHandle.self)
    static let patreon: [String:String] = { bundle.infoDictionary!["PATREON"] as! [String:String] }()
    static func string(forKey key: String) -> String? {
        patreon[key]
    }
    static internal let clientID: String = {
        string(forKey:"CLIENT_ID") ?? Patreon.Provenance.clientID
    }()
    static internal let clientSecret: String = {
        string(forKey:"CLIENT_SECRET") ?? Patreon.Provenance.clientSecret
    }()
    static internal let campaignID: String = {
        string(forKey:"CAMPAIGN_ID") ?? Patreon.Provenance.campaignID
    }()
    static internal let redirectURL: String = {
        string(forKey:"REDIRECT_URL") ?? Patreon.Provenance.redirectURL
    }()
    static internal let callbackURLScheme: String = {
        string(forKey:"CALLBACK_URL_SCHEME") ?? Patreon.Provenance.callbackURLScheme
    }()
    static internal let keychainService: String = {
        bundle.infoDictionary!["KEYCHAIN_SERIVCE"] as? String ?? Patreon.Provenance.keychainService
    }()
    
    static let patreonInfo = URL(string: "https://cdn.altstore.io/file/altstore/altstore/patreon.json")!
    package enum Staging {
        static let patreonInfo = URL(string: "https://f000.backblazeb2.com/file/altstore-staging/altstore/patreon.json")!
    }
    
    internal enum Patreon {
        internal enum Provenance {
            static internal let callbackURLScheme = "provenance"
            static internal let campaignID = "2198356"
            static internal let clientID = "nSNDsv4K_SHF_kLfNgjTi52cU2bTuwunxu9g6j61WtQxoaGEHy1aNAZydM4VcMiz"
            static internal let clientSecret = "QkHx9MirO0QYvVcJzrsoRU5IO9qusihvbwaXVQRlUohnS631CQKunSkDDVAnJbkZ"
            static internal let keychainService = "com.provenance.patreon"
            static internal let redirectURL = "https://provenance-emu.com/patreon_redirect"
        }
    }
}
