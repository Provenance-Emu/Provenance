//
//  BezelImportTests.swift
//  PVSettings
//
//  Reading a RetroArch bezel overlay: its `.cfg`, and the screen in its image.
//

import Foundation
import Testing
@testable import PVSettings

@Suite("RetroArchOverlayConfig")
struct RetroArchOverlayConfigTests {

    /// The five lines every Bezel Project overlay has.
    private let bezelProject = """
    overlays = 1

    overlay0_overlay = "ActRaiser (USA).png"

    overlay0_full_screen = true

    overlay0_descs = 0
    """

    @Test("A Bezel Project overlay names its image")
    func bezelProjectOverlay() throws {
        let config = try RetroArchOverlayConfig(text: bezelProject)
        #expect(config.imageName == "ActRaiser (USA).png")
        #expect(config.overlayCount == 1)
        #expect(config.isFullScreen == true)
        #expect(config.displayName == nil)
        #expect(config.rect == nil)
    }

    @Test("Values work without quotes, with odd spacing, comments and Windows line ends")
    func loosenessOfTheFormat() throws {
        let text = "# a bezel\r\n  overlays=1\r\noverlay0_overlay   =Super-Nintendo.png   # the art\r\n"
            + "overlay0_name = \"My TV\" # quoted\r\noverlay0_rect = \"0.1, 0.2,0.8,0.6\"\r\noverlay0_full_screen = false\r\n"
        let config = try RetroArchOverlayConfig(text: text)
        #expect(config.imageName == "Super-Nintendo.png")
        #expect(config.displayName == "My TV")
        #expect(config.isFullScreen == false)
        #expect(config.rect == CGRect(x: 0.1, y: 0.2, width: 0.8, height: 0.6))
    }

    @Test("A folder in the image's path is dropped, with either slash")
    func imagePath() throws {
        #expect(try RetroArchOverlayConfig(text: "overlay0_overlay = \"borders/tv/art.png\"").imageName == "art.png")
        #expect(try RetroArchOverlayConfig(text: "overlay0_overlay = C:\\overlays\\art.png").imageName == "art.png")
    }

    @Test("A touch-control overlay is refused")
    func touchControls() {
        let text = "overlays = 2\noverlay0_overlay = pad.png\noverlay0_descs = 14\noverlay0_desc0 = \"a,0.9,0.8,radial,0.05,0.05\""
        #expect(throws: RetroArchOverlayConfig.ParseError.touchControls(buttons: 14)) {
            try RetroArchOverlayConfig(text: text)
        }
    }

    @Test("Several overlays: the first is used and the count is kept")
    func severalOverlays() throws {
        let config = try RetroArchOverlayConfig(text: "overlays = 3\noverlay0_overlay = one.png\noverlay1_overlay = two.png")
        #expect(config.imageName == "one.png")
        #expect(config.overlayCount == 3)
    }

    @Test("A file that names no image is refused", arguments: ["", "overlays = 1", "overlay0_overlay = \"\"", "input_overlay = \"/x/y.cfg\""])
    func noImage(text: String) {
        #expect(throws: RetroArchOverlayConfig.ParseError.noImage) {
            try RetroArchOverlayConfig(text: text)
        }
    }

    @Test("Unknown keys and broken lines are ignored")
    func unknownKeys() throws {
        let text = "video_scale_integer = true\nnot a line\n= orphan\noverlay0_overlay = art.png\noverlay0_alpha_mod = 2.0"
        #expect(try RetroArchOverlayConfig(text: text).imageName == "art.png")
        #expect(RetroArchOverlayConfig.values(in: text)["video_scale_integer"] == "true")
    }
}

@Suite("BezelScreenDetector")
struct BezelScreenDetectorTests {

    private typealias Detector = BezelScreenDetector

    /// An image's alpha, drawn in code: opaque everywhere until something is cut out of it.
    private struct Canvas {
        let width: Int
        let height: Int
        var alpha: [UInt8]

        init(width: Int = 192, height: Int = 108) {
            self.width = width
            self.height = height
            alpha = [UInt8](repeating: 255, count: width * height)
        }

        /// Sets the alpha of a rect, optionally with rounded corners.
        mutating func fill(_ rect: CGRect, alpha value: UInt8 = 0, cornerRadius: Int = 0) {
            for row in Int(rect.minY) ..< Int(rect.maxY) {
                for column in Int(rect.minX) ..< Int(rect.maxX) {
                    if cornerRadius > 0 {
                        let nearX = min(column - Int(rect.minX), Int(rect.maxX) - 1 - column)
                        let nearY = min(row - Int(rect.minY), Int(rect.maxY) - 1 - row)
                        if nearX < cornerRadius, nearY < cornerRadius {
                            let (deltaX, deltaY) = (cornerRadius - nearX, cornerRadius - nearY)
                            if deltaX * deltaX + deltaY * deltaY > cornerRadius * cornerRadius { continue }
                        }
                    }
                    alpha[row * width + column] = value
                }
            }
        }

        var screen: Result<CGRect, Detector.Refusal> {
            Detector.screenRect(alpha: alpha, width: width, height: height)
        }
    }

    @Test("A plain hole is found exactly")
    func plainHole() {
        var canvas = Canvas()
        let hole = CGRect(x: 24, y: 2, width: 144, height: 104)
        canvas.fill(hole)
        #expect(canvas.screen == .success(hole))
    }

    @Test("Rounded corners do not shrink the screen")
    func roundedCorners() {
        var canvas = Canvas()
        let hole = CGRect(x: 24, y: 2, width: 144, height: 104)
        canvas.fill(hole, cornerRadius: 12)
        #expect(canvas.screen == .success(hole))
    }

    @Test("A shadow ring inside the frame: the screen ends where the art turns mostly opaque")
    func shadowRing() {
        var canvas = Canvas()
        // Frame art fading in: mostly opaque, then mostly clear, then the clear hole.
        canvas.fill(CGRect(x: 20, y: 2, width: 152, height: 104), alpha: 200)
        canvas.fill(CGRect(x: 24, y: 4, width: 144, height: 100), alpha: 60)
        canvas.fill(CGRect(x: 28, y: 6, width: 136, height: 96), alpha: 0)
        #expect(canvas.screen == .success(CGRect(x: 24, y: 4, width: 144, height: 100)))
    }

    @Test("Stray see-through pixels, joined to the screen or not, do not move it")
    func strayPixels() {
        var canvas = Canvas()
        let hole = CGRect(x: 40, y: 0, width: 110, height: 108)
        canvas.fill(hole)
        // A thin see-through streak running from the hole to the right edge (as in the Game Boy art).
        canvas.fill(CGRect(x: 150, y: 50, width: 42, height: 3))
        // A separate speck in a corner.
        canvas.fill(CGRect(x: 2, y: 2, width: 4, height: 4))
        #expect(canvas.screen == .success(hole))
    }

    @Test("An off-centre hole is found where it is")
    func offCentre() {
        var canvas = Canvas()
        let hole = CGRect(x: 100, y: 10, width: 80, height: 60)
        canvas.fill(hole)
        #expect(canvas.screen == .success(hole))
    }

    @Test("Images with no usable screen are refused")
    func refusals() {
        #expect(Canvas().screen == .failure(.noScreen))

        var tiny = Canvas()
        tiny.fill(CGRect(x: 10, y: 10, width: 20, height: 20))
        #expect(tiny.screen == .failure(.tooSmall))

        var empty = Canvas()
        empty.fill(CGRect(x: 0, y: 0, width: 192, height: 108))
        #expect(empty.screen == .failure(.nothingToShow))

        var two = Canvas()
        two.fill(CGRect(x: 10, y: 10, width: 80, height: 88))
        two.fill(CGRect(x: 102, y: 10, width: 80, height: 88))
        #expect(two.screen == .failure(.twoScreens))
    }

    @Test("A small second hole beside the screen is ignored")
    func smallSecondHole() {
        var canvas = Canvas()
        let hole = CGRect(x: 10, y: 4, width: 120, height: 100)
        canvas.fill(hole)
        canvas.fill(CGRect(x: 150, y: 40, width: 30, height: 30))
        #expect(canvas.screen == .success(hole))
    }

    @Test("A buffer shorter than the image is refused, not read past its end")
    func shortBuffer() {
        #expect(Detector.screenRect(alpha: [0, 0, 0], width: 4, height: 4) == .failure(.noScreen))
        #expect(Detector.screenRect(alpha: [], width: 0, height: 0) == .failure(.noScreen))
    }
}

@Suite("BezelPictureFit")
struct BezelPictureFitTests {

    @Test("A picture nearly the screen's shape fills it")
    func nearlyTheSameShape() {
        // The Bezel Project's TV hole is 1432x1073 (1.335) for a 4:3 picture.
        let screen = CGRect(x: 244, y: 3, width: 1432, height: 1073)
        #expect(BezelPictureFit.rect(aspect: CGSize(width: 4, height: 3), in: screen) == screen)
        #expect(BezelPictureFit.rect(aspect: CGSize(width: 1.38, height: 1), in: screen) == screen)
    }

    @Test("A wider picture gets bars above and below, a taller one at the sides")
    func differentShape() {
        let screen = CGRect(x: 100, y: 0, width: 400, height: 300)
        #expect(BezelPictureFit.rect(aspect: CGSize(width: 16, height: 9), in: screen)
                == CGRect(x: 100, y: 37.5, width: 400, height: 225))
        #expect(BezelPictureFit.rect(aspect: CGSize(width: 1, height: 1), in: screen)
                == CGRect(x: 150, y: 0, width: 300, height: 300))
        // A 3:2 handheld picture in a tall hole.
        let tall = CGRect(x: 0, y: 0, width: 200, height: 400)
        #expect(BezelPictureFit.rect(aspect: CGSize(width: 3, height: 2), in: tall).size == CGSize(width: 200, height: 200.0 / 1.5))
    }

    @Test("Shapes with no size leave the screen as it is")
    func degenerate() {
        let screen = CGRect(x: 0, y: 0, width: 10, height: 10)
        #expect(BezelPictureFit.rect(aspect: .zero, in: screen) == screen)
        #expect(BezelPictureFit.rect(aspect: CGSize(width: 4, height: 3), in: .zero) == .zero)
    }
}
