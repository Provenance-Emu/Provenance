//
//  TVBezelArtwork.swift
//  PVUI
//
//  A TV's cabinet and room, drawn from its format 2 skin document.
//

import CoreGraphics
import Foundation
import ImageIO
import SkinKit2Core
import SkinKit2Render
import UniformTypeIdentifiers

/// A TV's skin document resolved on the TV canvas.
///
/// The document's one screen node is the tube: its frame is the only statement of where the
/// picture goes and what shape it has. Everything else in the document is artwork.
struct TVBezelArtwork {

    enum ArtworkError: Error, Equatable {
        /// The document must have exactly one screen node (it has this many).
        case screenCount(Int)
        case emptyTube
    }

    /// The canvas every TV is drawn on, in points: the format's `tv` layout.
    static let canvas = CGSize(width: 1920, height: 1080)

    /// The tube in canvas points.
    let tubeRect: CGRect
    private let resolution: Skin2Resolution

    /// The tube's width over its height.
    var tubeAspect: CGFloat { tubeRect.width / tubeRect.height }
    /// The tube's height as a fraction of the canvas's.
    var tubeHeightFraction: CGFloat { tubeRect.height / Self.canvas.height }

    /// - Parameter data: the skin document (`skin.json` contents).
    init(data: Data) throws {
        let document = try Skin2Document.load(data: data)
        let environment = Skin2Environment(size: .init(width: Self.canvas.width, height: Self.canvas.height),
                                           orientation: .landscape, device: .tv, displayType: .standard)
        let resolution = Skin2Resolver.resolve(document, in: environment)
        let screens = resolution.screens
        guard screens.count == 1, let frame = screens.first?.frame else {
            throw ArtworkError.screenCount(screens.count)
        }
        guard frame.width > 0, frame.height > 0 else { throw ArtworkError.emptyTube }
        self.resolution = resolution
        tubeRect = CGRect(x: frame.x, y: frame.y, width: frame.width, height: frame.height)
    }

    /// The bundled artwork of `bezel`.
    init(bezel: TVBezel) throws {
        guard let url = TVBezelCatalog.folderURL?.appendingPathComponent(bezel.artwork) else {
            throw CocoaError(.fileNoSuchFile)
        }
        try self.init(data: Data(contentsOf: url))
    }

    /// The cabinet and room as an image `pixelWidth` pixels wide (the canvas scaled uniformly).
    func image(pixelWidth: CGFloat) -> CGImage? {
        guard pixelWidth > 0 else { return nil }
        return Skin2Renderer.image(resolution, scale: pixelWidth / Self.canvas.width)
    }

    /// The same as PNG data, the form a preset's texture is loaded from.
    func pngData(pixelWidth: CGFloat) -> Data? {
        guard let image = image(pixelWidth: pixelWidth) else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }
}
