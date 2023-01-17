//
//  PatreonAPI+ASWebAuthenticationPresentationContextProviding.swift
//  PVPatreon
//
//  Created by Joseph Mattiello on 12/17/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation
#if canImport(AuthenticationServices)
import AuthenticationServices

extension PatreonAPI: ASWebAuthenticationPresentationContextProviding {
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return UIApplication.shared.keyWindow ?? UIWindow()
    }
}
#endif
