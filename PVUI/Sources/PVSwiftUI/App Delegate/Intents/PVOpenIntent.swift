//
//  PVOpenIntent.swift
//  Provenance
//
//  Created by Joseph Mattiello
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import Foundation
import Intents

#if os(iOS)
@available(iOS 14.0, *)
@objc(PVOpenIntent)
class PVOpenIntent: INIntent {
    var md5: String?
    var gameName: String?
    var systemName: String?

    override init() {
        super.init()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        md5 = coder.decodeObject(forKey: "md5") as? String
        gameName = coder.decodeObject(forKey: "gameName") as? String
        systemName = coder.decodeObject(forKey: "systemName") as? String
    }

    override func encode(with coder: NSCoder) {
        super.encode(with: coder)
        coder.encode(md5, forKey: "md5")
        coder.encode(gameName, forKey: "gameName")
        coder.encode(systemName, forKey: "systemName")
    }

    convenience init(md5: String? = nil, gameName: String? = nil, systemName: String? = nil) {
        self.init()
        self.md5 = md5
        self.gameName = gameName
        self.systemName = systemName
    }
}
#endif
