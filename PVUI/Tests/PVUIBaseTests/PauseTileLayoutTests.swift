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
}
