import CoreGraphics
import Testing
@testable import PVUIBase

@Suite("Pause tile geometry")
struct PauseTileLayoutTests {
    @Test("Portrait panel fits four compact tiles")
    func portrait() {
        #expect(PauseTileLayout.columns(panelWidth: 370) == 4)
        #expect(PauseTileLayout.columns(panelWidth: 358) == 4)
    }

    @Test("Wide panels stop at eight columns")
    func wide() {
        #expect(PauseTileLayout.columns(panelWidth: 816) == 8)
        #expect(PauseTileLayout.columns(panelWidth: 1100) == 8)
    }

    @Test("Accessibility type gives labels more space")
    func accessibility() {
        #expect(PauseTileLayout.columns(panelWidth: 370, accessibility: true) == 2)
        #expect(PauseTileLayout.columns(panelWidth: 816, accessibility: true) == 5)
    }

    @Test("No layout requests a negative count or exceeds its available width")
    func bounds() {
        for width in stride(from: 0.0, through: 1600.0, by: 1) {
            let count = PauseTileLayout.columns(panelWidth: width)
            #expect((1...8).contains(count))
            if count > 1 {
                let needed = Double(count) * PauseTileLayout.minimumWidth + Double(count - 1) * PauseTileLayout.spacing
                #expect(needed <= width - PauseTileLayout.contentInset * 2)
            }
        }
    }

    @Test("Sections of four cells need four columns, however many fit")
    func shortSectionsNarrowTheGrid() {
        #expect(PauseTileLayout.balancedColumns(tileCounts: [4, 4, 4, 1, 4], maxColumns: 8) == 4)
    }

    @Test("A section that wraps is balanced across its rows instead of filling the first")
    func wrappedSectionIsBalanced() {
        #expect(PauseTileLayout.balancedColumns(tileCounts: [9], maxColumns: 8) == 5)
        #expect(PauseTileLayout.balancedColumns(tileCounts: [17], maxColumns: 8) == 6)
        #expect(PauseTileLayout.balancedColumns(tileCounts: [16], maxColumns: 8) == 8)
    }

    @Test("The widest section decides")
    func widestSectionDecides() {
        #expect(PauseTileLayout.balancedColumns(tileCounts: [3, 9, 4], maxColumns: 8) == 5)
        #expect(PauseTileLayout.balancedColumns(tileCounts: [8, 3], maxColumns: 8) == 8)
    }

    @Test("Narrowing never adds a row to any section")
    func narrowingKeepsRowCounts() {
        for limit in 1...8 {
            for count in 1...40 {
                let columns = PauseTileLayout.balancedColumns(tileCounts: [count], maxColumns: limit)
                #expect((1...limit).contains(columns))
                #expect((count + columns - 1) / columns == (count + limit - 1) / limit)
            }
        }
    }

    @Test("Nothing to lay out keeps every column")
    func emptyKeepsFullWidth() {
        #expect(PauseTileLayout.balancedColumns(tileCounts: [], maxColumns: 6) == 6)
        #expect(PauseTileLayout.balancedColumns(tileCounts: [0, 0], maxColumns: 6) == 6)
        #expect(PauseTileLayout.balancedColumns(tileCounts: [5], maxColumns: 0) == 1)
    }

    /// The owner's iPad screenshot: an eight-column panel whose sections hold four cells at most.
    @Test("A panel of four-cell sections is half as wide, with the same cells")
    func panelShrinksToItsColumns() {
        let fit = PauseTileLayout.fit(fullWidth: 840, maxColumns: 8, tileCounts: [4, 4, 4, 1, 4],
                                      inset: 12, spacing: 6, minimumWidth: 380)
        let cell = (840.0 - 24 - 6 * 7) / 8
        #expect(fit.columns == 4)
        #expect(abs(fit.width - (cell * 4 + 6 * 3 + 24)) < 0.001)
        #expect(fit.width < 840 / 2 + 12)
    }

    @Test("The panel never shrinks below the room its header needs, nor grows past the full width")
    func panelWidthBounds() {
        let narrow = PauseTileLayout.fit(fullWidth: 840, maxColumns: 8, tileCounts: [1],
                                         inset: 12, spacing: 6, minimumWidth: 380)
        #expect(narrow == PauseTileLayout.Fit(columns: 1, width: 380))
        let phone = PauseTileLayout.fit(fullWidth: 361, maxColumns: 4, tileCounts: [2],
                                        inset: 12, spacing: 6, minimumWidth: 380)
        #expect(phone == PauseTileLayout.Fit(columns: 2, width: 361))
    }

    @Test("A full section, or no grid at all, keeps the full width")
    func fullWidthCases() {
        let full = PauseTileLayout.Fit(columns: 8, width: 840)
        #expect(PauseTileLayout.fit(fullWidth: 840, maxColumns: 8, tileCounts: [8, 2],
                                    inset: 12, spacing: 6, minimumWidth: 380) == full)
        #expect(PauseTileLayout.fit(fullWidth: 840, maxColumns: 8, tileCounts: [],
                                    inset: 12, spacing: 6, minimumWidth: 380) == full)
    }

    @Test("A page's grid height counts its rows, titles and dividers")
    func gridHeight() {
        let height = { (groups: [(titled: Bool, count: Int)]) in
            PauseTileLayout.gridHeight(groups: groups, columns: 4, tileHeight: 70, spacing: 6,
                                       titleHeight: 14, titleGap: 6, sectionSpacing: 12)
        }
        #expect(height([]) == 0)
        #expect(height([(titled: false, count: 0)]) == 0)
        // One row, then two rows (70 + 6 + 70).
        #expect(height([(titled: false, count: 4)]) == 70)
        #expect(height([(titled: false, count: 5)]) == 146)
        // A titled group adds its title and gap; the next group adds a divider with spacing around it.
        #expect(height([(titled: true, count: 3), (titled: true, count: 1)]) == (20 + 70) + 25 + (20 + 70))
    }
}
