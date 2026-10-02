//
//  LibraryGridTests.swift
//  PVSwiftUITests
//

import CoreGraphics
import Testing
@testable import PVSwiftUI

#if !os(tvOS)
@Suite("LibraryGrid")
struct LibraryGridTests {

    @Test("Phones in portrait keep the four columns they always had",
          arguments: [375.0, 390.0, 393.0, 402.0, 430.0, 440.0])
    func phonePortrait(width: Double) {
        #expect(LibraryGrid.automaticColumns(forWidth: width) == 4)
    }

    @Test("Wider grids get more columns instead of bigger covers",
          arguments: [(744.0, 5), (820.0, 5), (1024.0, 6), (1180.0, 7), (1280.0, 8), (1366.0, 9)])
    func widerGrids(width: Double, expected: Int) {
        #expect(LibraryGrid.automaticColumns(forWidth: width) == expected)
    }

    @Test("Growing the width never removes a column")
    func monotonic() {
        var previous = 0
        for width in stride(from: 320.0, through: 2000.0, by: 1.0) {
            let columns = LibraryGrid.automaticColumns(forWidth: width)
            #expect(columns >= previous, "columns dropped at \(width)pt")
            previous = columns
        }
    }

    @Test("An unmeasured grid lays out as a portrait phone")
    func unmeasured() {
        #expect(LibraryGrid.automaticColumns(forWidth: 0) == 4)
    }

    @Test("The zoom adjustment shifts the count and is clamped to its range")
    func adjustment() {
        #expect(LibraryGrid.columns(forWidth: 390, adjustment: 0) == 4)
        #expect(LibraryGrid.columns(forWidth: 390, adjustment: 2) == 6)
        #expect(LibraryGrid.columns(forWidth: 390, adjustment: -3) == 1)
        #expect(LibraryGrid.columns(forWidth: 390, adjustment: -99) == 1)
        #expect(LibraryGrid.columns(forWidth: 390, adjustment: 99) == 4 + LibraryGrid.adjustmentRange.upperBound)
        #expect(LibraryGrid.columns(forWidth: 1024, adjustment: -3) == 3)
    }
}
#endif
