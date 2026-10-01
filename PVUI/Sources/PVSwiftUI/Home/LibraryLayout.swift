//
//  LibraryLayout.swift
//  PVUI
//

import CoreGraphics

/// Shared layout metrics for the Home and per-console library pages.
enum LibraryLayout {
    /// Bottom inset that keeps scrolling content clear of the page-dots index.
    /// Applied once per page; don't stack it with other bottom padding.
    static let pageIndexClearance: CGFloat = 64
}
