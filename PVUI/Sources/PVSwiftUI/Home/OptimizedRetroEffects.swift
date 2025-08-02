//
//  OptimizedRetroEffects.swift
//  PVUI
//
//  Created by Cascade on 8/1/25.
//

import SwiftUI
import PVThemes

/// Optimized retro effects with pre-computed paths and reduced GeometryReader usage
/// Significantly improves performance by caching expensive Path calculations
struct OptimizedRetroEffects: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    
    // Pre-computed static paths for better performance
    private static let scanlineCache = PathCache()
    private static let lcdCache = PathCache()
    
    /// Environment value for reduce motion setting
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        ZStack {
            // Subtle color tint overlay for retrowave effect
            LinearGradient(
                gradient: Gradient(colors: [
                    (themeManager.currentPalette.defaultTintColor.swiftUIColor ?? RetroTheme.retroPink).opacity(0.1),
                    RetroTheme.retroPurple.opacity(0.05)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Optimized scanlines using cached paths
            CachedPathView(
                cache: Self.scanlineCache,
                cacheKey: "scanlines",
                stroke: .black.opacity(0.3),
                lineWidth: 1
            ) { size in
                createScanlinePath(for: size)
            }
            
            // Optimized LCD effect using cached paths
            CachedPathView(
                cache: Self.lcdCache,
                cacheKey: "lcd",
                stroke: .black.opacity(0.1),
                lineWidth: 1
            ) { size in
                createLCDPath(for: size)
            }
            
            // Subtle vignette effect
            RadialGradient(
                gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.3)]),
                center: .center,
                startRadius: 50,
                endRadius: 150
            )
        }
        .allowsHitTesting(false)
        .drawingGroup() // Use Metal rendering for the entire effect
    }
    
    // MARK: - Path Creation Methods
    
    private func createScanlinePath(for size: CGSize) -> Path {
        var path = Path()
        stride(from: 0, to: size.height, by: 2).forEach { y in
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
        }
        return path
    }
    
    private func createLCDPath(for size: CGSize) -> Path {
        var path = Path()
        stride(from: 0, to: size.width, by: 3).forEach { x in
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
        }
        return path
    }
}

/// Cache for storing pre-computed Path objects to avoid expensive recalculations
class PathCache: ObservableObject {
    private var cache: [String: (size: CGSize, path: Path)] = [:]
    
    func path(for key: String, size: CGSize, creator: (CGSize) -> Path) -> Path {
        // Check if we have a cached path for this size
        if let cached = cache[key], cached.size == size {
            return cached.path
        }
        
        // Create new path and cache it
        let newPath = creator(size)
        cache[key] = (size: size, path: newPath)
        
        // Limit cache size
        if cache.count > 10 {
            let keysToRemove = Array(cache.keys.prefix(cache.count - 8))
            for key in keysToRemove {
                cache.removeValue(forKey: key)
            }
        }
        
        return newPath
    }
}

/// View that uses cached paths for better performance
private struct CachedPathView: View {
    let cache: PathCache
    let cacheKey: String
    let stroke: Color
    let lineWidth: CGFloat
    let pathCreator: (CGSize) -> Path
    
    var body: some View {
        GeometryReader { geometry in
            let path = cache.path(for: cacheKey, size: geometry.size, creator: pathCreator)
            path.stroke(stroke, lineWidth: lineWidth)
        }
    }
}

/// Lightweight version of retro effects for better performance when many items are visible
struct LightweightRetroEffects: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        // Only the essential visual effects
        LinearGradient(
            gradient: Gradient(colors: [
                (themeManager.currentPalette.defaultTintColor.swiftUIColor ?? RetroTheme.retroPink).opacity(0.05),
                RetroTheme.retroPurple.opacity(0.02)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .allowsHitTesting(false)
    }
}
