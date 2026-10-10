//
//  LibretroCoreBadge.swift
//  PVUIBase
//
//  Created by Provenance Contributors on 2026-10-10.
//

import SwiftUI

/// The RetroArch mark, tinted like the text around it. Core names no longer carry a
/// "(RetroArch)" suffix, so this is how a list tells a libretro core (thin wrapper)
/// from a native one. The asset is a template image; set `foregroundColor` to tint it.
public struct LibretroCoreBadge: View {
    /// Asset in PVUIBase's `SystemIcons.xcassets`.
    public static let assetName = "retroarch"

    private let size: CGFloat

    public init(size: CGFloat = 16) {
        self.size = size
    }

    public var body: some View {
        Image(Self.assetName, bundle: BundleLoader.myBundle)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityLabel("libretro core")
    }
}
