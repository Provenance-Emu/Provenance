//
//  MenuButtonPlacement.swift
//  PVUIBase
//
//  Where the floating menu button goes when on-screen controls share its corner.
//

import CoreGraphics

enum MenuButtonPlacement {
    static let size = CGSize(width: 42, height: 42)
    /// Clear space kept between the button and any control.
    static let spacing: CGFloat = 8
    /// Positions tried before giving up and using the preferred one.
    private static let maxCandidates = 16

    /// The button's frame: `preferred` when no control is in the way, else the nearest spot found
    /// by stepping below, then beside, each control that blocks it. Moved spots stay inside
    /// `bounds`. When nothing fits, `preferred`.
    static func frame(preferred: CGRect, avoiding controls: [CGRect], within bounds: CGRect) -> CGRect {
        let obstacles = controls.filter { !$0.isEmpty }.map { $0.insetBy(dx: -spacing, dy: -spacing) }
        var candidates = [preferred]
        var tried = 0
        while !candidates.isEmpty, tried < maxCandidates {
            let candidate = candidates.removeFirst()
            tried += 1
            let blockers = obstacles.filter { $0.intersects(candidate) }
            guard let lowest = blockers.map(\.maxY).max(), let rightmost = blockers.map(\.maxX).max() else {
                return candidate
            }
            let below = CGRect(origin: CGPoint(x: candidate.minX, y: lowest), size: candidate.size)
            let beside = CGRect(origin: CGPoint(x: rightmost, y: candidate.minY), size: candidate.size)
            candidates += [below, beside].filter { bounds.contains($0) }
        }
        return preferred
    }
}
