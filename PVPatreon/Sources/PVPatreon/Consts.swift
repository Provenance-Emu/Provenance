//
//  Consts.swift
//  PVPatreon
//
//  Created by Joseph Mattiello on 12/17/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation

private class PVPatreonHandle: NSObject { }
internal enum Const {
    static let bundle: Bundle = Bundle(for: PVPatreonHandle.self)
    static let patreon: [String:String] = { bundle.infoDictionary!["PATREON"] as! [String:String] }()
    static func string(forKey key: String) -> String {
        patreon[key] ?? ""
    }
    static internal let clientID: String = {
        string(forKey:"CLIENT_ID")
    }()
    static internal let clientSecret: String = {
        string(forKey:"CLIENT_SECRET")
    }()
    static internal let campaignID: String = {
        string(forKey:"CAMPAIGN_ID")
    }()
    static internal let redirectURL: String = {
        string(forKey:"REDIRECT_URL")
    }()
    static internal let callbackURLScheme: String = {
        string(forKey:"CALLBACK_URL_SCHEME")
    }()
    static internal let keychainService: String = {
        bundle.infoDictionary!["KEYCHAIN_SERIVCE"] as! String
    }()
    
    internal enum Patreon {
        internal enum Provenance {
            static internal let clientID = "nSNDsv4K_SHF_kLfNgjTi52cU2bTuwunxu9g6j61WtQxoaGEHy1aNAZydM4VcMiz"
            static internal let clientSecret = "QkHx9MirO0QYvVcJzrsoRU5IO9qusihvbwaXVQRlUohnS631CQKunSkDDVAnJbkZ"
            static internal let campaignID = "2198356"
        }
    }
}
