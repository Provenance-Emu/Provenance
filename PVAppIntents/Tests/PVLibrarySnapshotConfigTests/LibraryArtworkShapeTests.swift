// Copyright © 2026 Provenance Emu. All rights reserved.

import XCTest
@testable import PVLibrarySnapshotConfig

final class LibraryArtworkShapeTests: XCTestCase {
    func testPortraitGameCubeAndWiiCoversUsePoster() {
        for size in [CGSize(width: 160, height: 224), CGSize(width: 600, height: 900)] {
            XCTAssertEqual(LibraryArtworkShape.shape(for: size), .poster)
        }
    }

    func testSquareAndLandscapeCustomCovers() {
        XCTAssertEqual(LibraryArtworkShape.shape(for: CGSize(width: 500, height: 500)), .square)
        XCTAssertEqual(LibraryArtworkShape.shape(for: CGSize(width: 900, height: 600)), .wide)
        XCTAssertEqual(LibraryArtworkShape.shape(for: CGSize(width: 1920, height: 1080)), .wide)
    }

    func testSmallCoverIsPaddedWithoutUpscalingOrCropping() throws {
        let source = CGSize(width: 160, height: 224)
        let layout = try XCTUnwrap(LibraryArtworkShape.poster.layout(for: source))
        XCTAssertEqual(layout.drawing.size, source)
        XCTAssertGreaterThanOrEqual(layout.drawing.minX, 0)
        XCTAssertGreaterThanOrEqual(layout.drawing.minY, 0)
        XCTAssertLessThanOrEqual(layout.drawing.maxX, layout.canvas.width)
        XCTAssertLessThanOrEqual(layout.drawing.maxY, layout.canvas.height)
        XCTAssertEqual(LibraryArtworkShape.shape(for: layout.canvas), .poster)
    }

    func testLargeCoverFitsFrameAndPreservesAspect() throws {
        for shape in LibraryArtworkShape.allCases {
            let source = CGSize(width: 2400, height: 3600)
            let layout = try XCTUnwrap(shape.layout(for: source))
            XCTAssertEqual(layout.canvas, shape.pixelSize)
            XCTAssertEqual(layout.drawing.width / layout.drawing.height, source.width / source.height, accuracy: 0.0001)
            XCTAssertGreaterThanOrEqual(layout.drawing.minX, 0)
            XCTAssertGreaterThanOrEqual(layout.drawing.minY, 0)
            XCTAssertLessThanOrEqual(layout.drawing.maxX, layout.canvas.width)
            XCTAssertLessThanOrEqual(layout.drawing.maxY, layout.canvas.height)
        }
    }

    func testInvalidDimensionsDoNotRender() {
        for size in [CGSize.zero, CGSize(width: -1, height: 2), CGSize(width: CGFloat.infinity, height: 2)] {
            XCTAssertNil(LibraryArtworkShape.poster.layout(for: size))
            XCTAssertEqual(LibraryArtworkShape.shape(for: size), .square)
        }
    }

    func testCacheURLChangesForRenderingVersionAndReplacedSource() {
        let first = ProvenanceSnapshotBuilder.coverFilename(gameID: "ABC", artworkKey: "same-url", sourceFingerprint: "first-bytes")
        let replaced = ProvenanceSnapshotBuilder.coverFilename(gameID: "ABC", artworkKey: "same-url", sourceFingerprint: "new-bytes")
        XCTAssertNotEqual(first, replaced)
        XCTAssertTrue(first.hasPrefix("cover_ABC_v2_"))
        XCTAssertEqual(first, ProvenanceSnapshotBuilder.coverFilename(gameID: "ABC", artworkKey: "same-url", sourceFingerprint: "first-bytes"))
    }
}
