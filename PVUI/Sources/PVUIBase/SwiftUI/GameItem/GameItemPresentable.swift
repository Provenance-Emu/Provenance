//
//  GameItemPresentable.swift
//  PVUIBase
//
//  Created by GPT-5.2 on 1/9/26.
//

import Foundation
import PVSystems

/// Minimal surface area needed to render a game cell/row without holding a live Realm object.
public protocol GameItemPresentable {
    var id: String { get }
    var title: String { get }
    var trueArtworkURL: String { get }
    var boxartAspectRatio: PVGameBoxArtAspectRatio { get }

    var publishDate: String? { get }
    var rating: Int { get }
    var lastPlayed: Date? { get }
    var playCount: Int { get }

    var systemShortName: String? { get }

    var isFavorite: Bool { get }
    var hasCloudAssets: Bool { get }
    var isDownloaded: Bool { get }

    var discCount: Int { get }
    var isInvalidated: Bool { get }
}
