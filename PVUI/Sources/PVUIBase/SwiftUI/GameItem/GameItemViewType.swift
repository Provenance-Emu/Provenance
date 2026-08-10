//
//  GameItemViewType.swift
//  Provenance
//
//  Created by Ian Clawson on 1/22/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation
import SwiftUI
import PVLibrary
import PVThemes

#if os(tvOS) || targetEnvironment(macCatalyst) || os(macOS)
    public let PVRowHeight: CGFloat = 300.0
#else
    public let PVRowHeight: CGFloat = 150.0
#endif

/// Shelf row height scale for Favorites / Recently Played carousels (`PVRowHeight *` this value)
/// on touch devices, where halving the row buys vertical space on a phone screen.
private let PVCompactShelfRowHeightScaleTouch: CGFloat = 0.5

/// Shelf row height scale for Favorites / Recently Played carousels (`PVRowHeight *` this value).
///
/// On a desktop window the halved row is what makes shelf titles unreadable — the title's max
/// width is the measured artwork width, so a 75pt cell clips a monospaced title to a few
/// characters. Desktop therefore uses `DesktopLibraryMetrics.shelfRowHeightScale` (full height,
/// matching the Most Played shelf). Runtime-gated, so iPhone / iPad / tvOS are unchanged.
public var PVCompactShelfRowHeightScale: CGFloat {
    DesktopLibraryMetrics.isDesktop
        ? DesktopLibraryMetrics.shelfRowHeightScale
        : PVCompactShelfRowHeightScaleTouch
}

public enum GameItemViewType {
    case cell
    case row

    var titleFontSize: CGFloat {
        switch self {
        case .cell:
            return 11
        case .row:
            return 15
        }
    }

    var subtitleFontSize: CGFloat {
        switch self {
        case .cell:
            return 8
        case .row:
            return 12
        }
    }
}


