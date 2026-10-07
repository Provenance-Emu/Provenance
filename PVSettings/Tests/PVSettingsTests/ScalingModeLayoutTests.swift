//
//  ScalingModeLayoutTests.swift
//  PVSettings
//

import Testing
@testable import PVSettings
import Foundation

@Suite("ScalingModeLayout")
struct ScalingModeLayoutTests {

    private let fourByThree: CGFloat = 4.0 / 3.0
    private let sixteenByNine: CGFloat = 16.0 / 9.0

    private func frame(_ mode: ScalingMode,
                       container: CGSize,
                       aspect: CGFloat,
                       nativeHeight: CGFloat = 480,
                       scale: CGFloat = 1) -> CGRect {
        ScalingModeLayout.frame(for: mode, container: container, contentAspect: aspect,
                                nativePixelHeight: nativeHeight, screenScale: scale)
    }

    // MARK: Stretch / fit / fill

    @Test("stretch fills the whole container")
    func stretch() {
        let container = CGSize(width: 800, height: 600)
        #expect(frame(.stretch, container: container, aspect: sixteenByNine) == CGRect(origin: .zero, size: container))
    }

    @Test("aspectFit letterboxes a 16:9 picture in a 4:3 container")
    func fitLetterbox() {
        let rect = frame(.aspectFit, container: CGSize(width: 800, height: 600), aspect: sixteenByNine)
        #expect(rect.width == 800)
        #expect(abs(rect.height - 450) < 0.001)
        #expect(rect.minX == 0)
        #expect(abs(rect.minY - 75) < 0.001)
    }

    @Test("aspectFit pillarboxes a 4:3 picture in a 16:9 container")
    func fitPillarbox() {
        let rect = frame(.aspectFit, container: CGSize(width: 1920, height: 1080), aspect: fourByThree)
        #expect(rect.height == 1080)
        #expect(abs(rect.width - 1440) < 0.001)
        #expect(abs(rect.minX - 240) < 0.001)
        #expect(rect.minY == 0)
    }

    @Test("aspectFill covers the container and overflows the long axis, centred")
    func fill() {
        let rect = frame(.aspectFill, container: CGSize(width: 1920, height: 1080), aspect: fourByThree)
        #expect(rect.width == 1920)
        #expect(abs(rect.height - 1440) < 0.001)
        #expect(rect.minX == 0)
        #expect(abs(rect.minY - -180) < 0.001)
        #expect(abs(rect.width / rect.height - fourByThree) < 0.0001)

        let wide = frame(.aspectFill, container: CGSize(width: 600, height: 800), aspect: sixteenByNine)
        #expect(wide.height == 800)
        #expect(abs(wide.width - 800 * sixteenByNine) < 0.001)
        #expect(wide.minX < 0)
    }

    // MARK: Integer scale

    @Test("integerScale picks the largest whole multiple of the native size")
    func integerScale() {
        // Native 640x480 px at 1x; 1920x1080 fits 2x (960px tall) but not 3x (1440px).
        let rect = frame(.integerScale, container: CGSize(width: 1920, height: 1080), aspect: fourByThree)
        #expect(abs(rect.height - 960) < 0.001)
        #expect(abs(rect.width - 1280) < 0.001)
        #expect(abs(rect.midX - 960) < 0.001)
        #expect(abs(rect.midY - 540) < 0.001)
    }

    @Test("integerScale works in device pixels, not points")
    func integerScalePixels() {
        // 852x393 pt at 3x = 2556x1179 px: 2x of 480 px is 960 px = 320 pt tall.
        let rect = frame(.integerScale, container: CGSize(width: 852, height: 393), aspect: fourByThree, scale: 3)
        #expect(abs(rect.height - 320) < 0.001)
        #expect(abs(rect.width - 640 / 3 * 2) < 0.001)
    }

    @Test("integerScale falls back to aspectFit when not even 1x fits")
    func integerScaleTooSmall() {
        let container = CGSize(width: 300, height: 200)
        let rect = frame(.integerScale, container: container, aspect: fourByThree)
        #expect(rect == frame(.aspectFit, container: container, aspect: fourByThree))
    }

    @Test("integerScale is limited by the width when that is the tighter axis")
    func integerScaleWidthBound() {
        // 16:9 native is 853.3x480 px; 1000 px wide only fits 1x even though 1000 px tall fits 2x.
        let rect = frame(.integerScale, container: CGSize(width: 1000, height: 1000), aspect: sixteenByNine)
        #expect(abs(rect.height - 480) < 0.001)
    }

    // MARK: Native resolution

    @Test("nativeResolution is 1:1 native pixels, centred")
    func native() {
        let rect = frame(.nativeResolution, container: CGSize(width: 1000, height: 800), aspect: fourByThree)
        #expect(abs(rect.width - 640) < 0.001)
        #expect(abs(rect.height - 480) < 0.001)
        #expect(abs(rect.midX - 500) < 0.001)
        #expect(abs(rect.midY - 400) < 0.001)
    }

    @Test("nativeResolution divides by the screen scale")
    func nativeScaled() {
        let rect = frame(.nativeResolution, container: CGSize(width: 393, height: 852), aspect: fourByThree, scale: 3)
        #expect(abs(rect.height - 160) < 0.001)
        #expect(abs(rect.width - 640 / 3) < 0.001)
    }

    @Test("nativeResolution larger than the container falls back to aspectFit")
    func nativeTooBig() {
        let container = CGSize(width: 400, height: 300)
        let rect = frame(.nativeResolution, container: container, aspect: fourByThree)
        #expect(rect == frame(.aspectFit, container: container, aspect: fourByThree))
    }

    // MARK: Degenerate input

    @Test("an empty container gives that same empty container back", arguments: ScalingMode.allCases)
    func emptyContainer(mode: ScalingMode) {
        let rect = frame(mode, container: .zero, aspect: fourByThree)
        #expect(rect == .zero)
    }

    @Test("an unusable aspect gives the whole container", arguments: ScalingMode.allCases)
    func unusableAspect(mode: ScalingMode) {
        let container = CGSize(width: 800, height: 600)
        let whole = CGRect(origin: .zero, size: container)
        #expect(frame(mode, container: container, aspect: 0) == whole)
        #expect(frame(mode, container: container, aspect: -1) == whole)
        #expect(frame(mode, container: container, aspect: .nan) == whole)
        #expect(frame(mode, container: container, aspect: .infinity) == whole)
    }

    @Test("integerScale and nativeResolution give the whole container without a native size")
    func missingNativeSize() {
        let container = CGSize(width: 800, height: 600)
        let whole = CGRect(origin: .zero, size: container)
        #expect(frame(.integerScale, container: container, aspect: fourByThree, nativeHeight: 0) == whole)
        #expect(frame(.nativeResolution, container: container, aspect: fourByThree, scale: 0) == whole)
    }

    @Test("every mode that keeps the aspect ratio returns a rect with the content's aspect",
          arguments: [ScalingMode.aspectFit, .aspectFill, .integerScale, .nativeResolution])
    func aspectPreserved(mode: ScalingMode) {
        for aspect in [fourByThree, sixteenByNine] {
            let rect = frame(mode, container: CGSize(width: 1194, height: 834), aspect: aspect, scale: 2)
            #expect(abs(rect.width / rect.height - aspect) < 0.0001)
        }
    }
}
