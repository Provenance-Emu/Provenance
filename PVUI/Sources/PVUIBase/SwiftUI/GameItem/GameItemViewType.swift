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


