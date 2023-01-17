//
//  File.swift
//  
//
//  Created by Joseph Mattiello on 1/10/23.
//

import Foundation

public
protocol PatreonDataManager: AnyObject {
    var patreonAccessToken: String? { get set }
    var patreonRefreshToken: String? { get set }
    var patreonCreatorAccessToken: String? { get set }
    var patreonAccountID: String?  { get set }
}

public
protocol AppleIDDataManager: AnyObject {
    var appleIDEmailAddress: String? { get set }
    var appleIDPassword: String? { get set }
}

public
protocol CodeSignDataManager: AnyObject {
    var signingCertificatePrivateKey: Data? { get set }
    var signingCertificateSerialNumber: String? { get set }
    var signingCertificate: Data? { get set }
    var signingCertificatePassword: String? { get set }
}

public
protocol DatabaseDataManager: AnyObject {
    var patreonAccounts: [PatreonAccount]? { get set }
}
