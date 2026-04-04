//
//  PVGame+GameItemPresentable.swift
//  PVUIBase
//
//  Created by GPT-5.2 on 1/9/26.
//

import Foundation
import PVRealm

extension PVGame: GameItemPresentable {
    public var md5: String { md5Hash }

    public var discCount: Int {
        let allFiles = relatedFiles.toArray()
        let uniqueFiles = Set(allFiles.compactMap { $0.url?.path })
        return uniqueFiles.count
    }
}
