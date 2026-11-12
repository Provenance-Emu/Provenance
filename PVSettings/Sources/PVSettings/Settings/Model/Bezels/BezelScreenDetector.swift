//
//  BezelScreenDetector.swift
//  PVSettings
//
//  Where the screen is in a bezel image, read from its transparency.
//

import Foundation

/// Finds the screen of a bezel image: the see-through area the game picture shows through.
///
/// RetroArch bezel overlays say nothing about where the screen is; the picture is simply drawn
/// behind the image. The screen is the largest connected see-through region. Its rect is the
/// span of rows and columns that region covers widely, so rounded corners, the soft shadow
/// ring inside a frame and stray see-through pixels do not move it.
public enum BezelScreenDetector {

    /// Why an image cannot be used as a bezel.
    public enum Refusal: Error, Equatable, Sendable {
        /// Nothing in the image is see-through.
        case noScreen
        /// The see-through area is too small to be a screen.
        case tooSmall
        /// Almost the whole image is see-through: there is no bezel to show.
        case nothingToShow
        /// Two see-through areas of similar size: a bezel for two screens.
        case twoScreens
    }

    /// A pixel is see-through when its alpha is below this.
    public static let seeThroughAlpha: UInt8 = 128
    /// The screen must cover at least this fraction of the image.
    public static let minimumScreenFraction = 0.10
    /// More see-through than this fraction of the image leaves nothing to show.
    public static let maximumScreenFraction = 0.97
    /// A second region at least this fraction of the first makes it a two-screen bezel.
    public static let secondScreenFraction = 0.5
    /// A row or column belongs to the screen when the region covers at least this fraction of
    /// its widest row or tallest column.
    public static let coverageFraction = 0.5

    /// One horizontal run of see-through pixels.
    private struct Run {
        let row: Int
        let start: Int
        /// One past the last pixel.
        let end: Int
        var length: Int { end - start }
    }

    /// - Parameters:
    ///   - alpha: one alpha value per pixel, row by row from the top, `width * height` long.
    /// - Returns: the screen in pixels, origin at the top left.
    public static func screenRect(alpha: [UInt8], width: Int, height: Int) -> Result<CGRect, Refusal> {
        alpha.withUnsafeBufferPointer { screenRect(alpha: $0, width: width, height: height) }
    }

    public static func screenRect(alpha: UnsafeBufferPointer<UInt8>, width: Int, height: Int) -> Result<CGRect, Refusal> {
        guard width > 0, height > 0, alpha.count >= width * height else { return .failure(.noScreen) }

        // Runs of see-through pixels, joined into regions where runs on neighbouring rows overlap.
        var runs: [Run] = []
        var parents: [Int] = []
        var previousRow = 0 ..< 0
        for row in 0 ..< height {
            let rowStart = runs.count
            let base = row * width
            var column = 0
            while column < width {
                guard alpha[base + column] < seeThroughAlpha else { column += 1; continue }
                let start = column
                while column < width, alpha[base + column] < seeThroughAlpha { column += 1 }
                runs.append(Run(row: row, start: start, end: column))
                parents.append(parents.count)
            }
            let currentRow = rowStart ..< runs.count
            var above = previousRow.lowerBound
            for index in currentRow {
                // Skip runs above that end before this one starts; they cannot touch later runs either.
                while above < previousRow.upperBound, runs[above].end <= runs[index].start { above += 1 }
                var candidate = above
                while candidate < previousRow.upperBound, runs[candidate].start < runs[index].end {
                    union(index, candidate, &parents)
                    candidate += 1
                }
            }
            previousRow = currentRow
        }
        guard !runs.isEmpty else { return .failure(.noScreen) }

        var areas: [Int: Int] = [:]
        for index in runs.indices {
            areas[find(index, &parents), default: 0] += runs[index].length
        }
        let ranked = areas.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
        let (screenRoot, screenArea) = (ranked[0].key, ranked[0].value)
        let imageArea = Double(width * height)
        guard Double(screenArea) <= imageArea * maximumScreenFraction else { return .failure(.nothingToShow) }
        guard Double(screenArea) >= imageArea * minimumScreenFraction else { return .failure(.tooSmall) }
        if ranked.count > 1, Double(ranked[1].value) >= Double(screenArea) * secondScreenFraction {
            return .failure(.twoScreens)
        }

        // How much of each row and column the screen's region covers.
        var rowCoverage = [Int](repeating: 0, count: height)
        var columnEdges = [Int](repeating: 0, count: width + 1)
        for index in runs.indices where find(index, &parents) == screenRoot {
            let run = runs[index]
            rowCoverage[run.row] += run.length
            columnEdges[run.start] += 1
            columnEdges[run.end] -= 1
        }
        var columnCoverage = [Int](repeating: 0, count: width)
        var running = 0
        for column in 0 ..< width {
            running += columnEdges[column]
            columnCoverage[column] = running
        }
        guard let rows = wideSpan(rowCoverage), let columns = wideSpan(columnCoverage) else {
            return .failure(.noScreen)
        }
        return .success(CGRect(x: columns.lowerBound, y: rows.lowerBound, width: columns.count, height: rows.count))
    }

    /// The first to the last index whose coverage is at least `coverageFraction` of the largest.
    private static func wideSpan(_ coverage: [Int]) -> ClosedRange<Int>? {
        guard let largest = coverage.max(), largest > 0 else { return nil }
        let threshold = Double(largest) * coverageFraction
        guard let first = coverage.firstIndex(where: { Double($0) >= threshold }),
              let last = coverage.lastIndex(where: { Double($0) >= threshold }) else { return nil }
        return first ... last
    }

    private static func find(_ index: Int, _ parents: inout [Int]) -> Int {
        var root = index
        while parents[root] != root { root = parents[root] }
        var node = index
        while parents[node] != root {
            let next = parents[node]
            parents[node] = root
            node = next
        }
        return root
    }

    private static func union(_ first: Int, _ second: Int, _ parents: inout [Int]) {
        let (rootA, rootB) = (find(first, &parents), find(second, &parents))
        guard rootA != rootB else { return }
        parents[max(rootA, rootB)] = min(rootA, rootB)
    }
}

/// Where the game picture goes inside a bezel's screen.
public enum BezelPictureFit {
    /// A picture whose shape is within this fraction of the screen's is stretched to fill it,
    /// so no sliver of black shows beside the artwork.
    public static let fillTolerance = 0.04

    /// - Parameters:
    ///   - aspect: the picture's shape (only the ratio matters).
    ///   - screen: the bezel's screen, in any unit.
    /// - Returns: the picture's rect in `screen`'s unit: the whole screen when the shapes nearly
    ///   agree, else the largest centred rect of the picture's shape.
    public static func rect(aspect: CGSize, in screen: CGRect) -> CGRect {
        guard aspect.width > 0, aspect.height > 0, screen.width > 0, screen.height > 0 else { return screen }
        let pictureRatio = Double(aspect.width / aspect.height)
        let screenRatio = Double(screen.width / screen.height)
        guard abs(pictureRatio / screenRatio - 1) > fillTolerance else { return screen }
        if pictureRatio > screenRatio {
            let height = screen.width / CGFloat(pictureRatio)
            return CGRect(x: screen.minX, y: screen.midY - height / 2, width: screen.width, height: height)
        }
        let width = screen.height * CGFloat(pictureRatio)
        return CGRect(x: screen.midX - width / 2, y: screen.minY, width: width, height: screen.height)
    }
}
