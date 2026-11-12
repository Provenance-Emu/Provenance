//
//  TVBezelLibrary.swift
//  PVUI
//
//  The bezels the player imported or downloaded: one folder in the library.
//

import CoreGraphics
import Foundation
import ImageIO
import PVFileSystem
import PVLogging
import PVSettings

/// Reads a bezel image: its size, where its screen is, and a copy sized for a display.
enum TVBezelImage {

    enum ImageError: Error, Equatable {
        /// Not an image ImageIO can read.
        case unreadable
        /// More pixels on a side than `maximumSide`.
        case tooLarge
        /// The image has no usable screen.
        case refused(BezelScreenDetector.Refusal)
    }

    /// Larger images than this on a side are refused, not decoded.
    static let maximumSide = 8192
    private static let bytesPerPixel = 4

    /// The image's size and its screen, both in pixels.
    static func analyze(_ url: URL) throws -> (size: CGSize, screen: CGRect) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { throw ImageError.unreadable }
        let (width, height) = (image.width, image.height)
        guard width > 0, height > 0 else { throw ImageError.unreadable }
        guard width <= maximumSide, height <= maximumSide else { throw ImageError.tooLarge }
        // Drawn as RGBA so every source format (paletted, grey, 16-bit) ends as 8-bit alpha.
        var pixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: width * bytesPerPixel, space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { throw ImageError.unreadable }
        var alpha = [UInt8](repeating: 0, count: width * height)
        for index in alpha.indices {
            alpha[index] = pixels[index * bytesPerPixel + bytesPerPixel - 1]
        }
        switch BezelScreenDetector.screenRect(alpha: alpha, width: width, height: height) {
        case .success(let screen): return (CGSize(width: width, height: height), screen)
        case .failure(let refusal): throw ImageError.refused(refusal)
        }
    }

    /// The image decoded no larger than `maxPixel` on its longer side.
    static func displayImage(_ url: URL, maxPixel: CGFloat) -> CGImage? {
        guard maxPixel >= 1, let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                        kCGImageSourceThumbnailMaxPixelSize: Int(maxPixel),
                                        kCGImageSourceShouldCacheImmediately: true]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}

/// The player's bezels: `Bezels/` in the library, beside `DeltaSkins/`.
///
/// `Imported/` holds the player's own files; a PNG put there by any means is picked up by
/// `refresh()`. `The Bezel Project/<repository>/` holds downloads. Beside each image the
/// library keeps `<image>.bezel.json` with its name, screen and system, so an image is read
/// once. A TV's id is its image's path inside the folder.
public final class TVBezelLibrary: @unchecked Sendable {

    public static let shared = TVBezelLibrary()

    /// Posted on the main queue when the library's contents change.
    public static let didChangeNotification = Notification.Name("PVTVBezelLibraryDidChangeNotification")

    static let folderName = "Bezels"
    static let importedFolder = "Imported"
    static let bezelProjectFolder = "The Bezel Project"
    static let sidecarSuffix = ".bezel.json"
    static let imageExtension = "png"
    static let configExtension = "cfg"
    static let idPrefix = "file:"

    /// Why a file was not imported.
    public enum ImportProblem: Error, Hashable, Sendable {
        case notAnImage
        case tooLarge
        case noScreen
        case screenTooSmall
        case nothingToShow
        case twoScreens
        /// A RetroArch touch-control overlay, not a bezel.
        case touchControls
        /// A `.cfg` naming an image that was not picked with it.
        case missingImage(String)
        case couldNotCopy

        init(_ error: Error) {
            switch error {
            case TVBezelImage.ImageError.tooLarge: self = .tooLarge
            case TVBezelImage.ImageError.refused(.noScreen): self = .noScreen
            case TVBezelImage.ImageError.refused(.tooSmall): self = .screenTooSmall
            case TVBezelImage.ImageError.refused(.nothingToShow): self = .nothingToShow
            case TVBezelImage.ImageError.refused(.twoScreens): self = .twoScreens
            case TVBezelImage.ImageError.unreadable: self = .notAnImage
            default: self = .couldNotCopy
            }
        }

        public var message: String {
            switch self {
            case .notAnImage: return String(localized: "It is not an image that can be read.")
            case .tooLarge: return String(localized: "The image is too large.")
            case .noScreen: return String(localized: "The image has no see-through area for the game to show through.")
            case .screenTooSmall: return String(localized: "The see-through area is too small to be a screen.")
            case .nothingToShow: return String(localized: "Almost the whole image is see-through, so there is no bezel to show.")
            case .twoScreens: return String(localized: "It is a bezel for two screens, which is not supported.")
            case .touchControls: return String(localized: "It is a touch-control overlay, not a bezel.")
            case .missingImage(let name): return String(localized: "Its image, \(name), was not picked with it.")
            case .couldNotCopy: return String(localized: "The file could not be copied into the library.")
            }
        }
    }

    public struct ImportResult: Sendable {
        public var imported: [TVBezel] = []
        /// File name and what was wrong with it.
        public var problems: [(file: String, problem: ImportProblem)] = []
    }

    /// What is kept beside an image.
    struct Sidecar: Codable, Equatable {
        static let currentVersion = 1
        var version = Sidecar.currentVersion
        var name: String
        /// Pixels: width, height.
        var size: [Double]
        /// Pixels from the top left: x, y, width, height.
        var screen: [Double]
        var system: String?
        var source: TVBezel.Source
        var listed: Bool
        /// Set when the image cannot be a bezel, so it is not read again.
        var refusal: String?
    }

    let rootURL: URL
    private let lock = NSLock()
    private var stored: [TVBezel] = []
    private var hasScanned = false

    /// - Parameter rootURL: the bezels folder; the library's own by default.
    init(rootURL: URL = URL.documentsPath.appendingPathComponent(TVBezelLibrary.folderName, isDirectory: true)) {
        self.rootURL = rootURL
    }

    // MARK: - Reading

    /// Every bezel on the device, listed in the picker or not, by name.
    public var bezels: [TVBezel] {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }

    /// The ones the picker shows.
    public var listed: [TVBezel] { bezels.filter(\.isListed) }

    public func bezel(id: String) -> TVBezel? {
        bezels.first { $0.id == id }
    }

    /// The bezel whose image is at `relativePath` inside the folder, if it is on the device.
    func bezel(relativePath: String) -> TVBezel? {
        bezel(id: Self.idPrefix + relativePath)
    }

    /// Reads the folder, taking in any PNG that was put into `Imported/` by hand. Slow the
    /// first time; call it off the main thread.
    public func refresh() {
        let fileManager = FileManager.default
        var found: [TVBezel] = []
        if let enumerator = fileManager.enumerator(at: rootURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for case let url as URL in enumerator where url.pathExtension.lowercased() == Self.imageExtension {
                guard let relativePath = relativePath(of: url) else { continue }
                var sidecar = readSidecar(for: url)
                if sidecar == nil, relativePath.hasPrefix(Self.importedFolder + "/") {
                    sidecar = adoptDroppedImage(url)
                }
                if let sidecar, let bezel = makeBezel(sidecar, imageURL: url, relativePath: relativePath) {
                    found.append(bezel)
                }
            }
        }
        found.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        replace(with: found)
    }

    /// Runs `refresh()` once per launch, in the background.
    public func refreshIfNeeded() {
        lock.lock()
        let needed = !hasScanned
        hasScanned = true
        lock.unlock()
        guard needed else { return }
        Task.detached(priority: .utility) { [self] in refresh() }
    }

    // MARK: - Adding

    /// Copies an image into the folder at `relativePath`, reads its screen and adds it.
    /// An image already there is replaced.
    @discardableResult
    func add(imageAt source: URL, relativePath: String, name: String, system: String?,
             source kind: TVBezel.Source, listed: Bool) throws -> TVBezel {
        let analysis = try TVBezelImage.analyze(source)
        let destination = rootURL.appendingPathComponent(relativePath)
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            if source.standardizedFileURL != destination.standardizedFileURL {
                if fileManager.fileExists(atPath: destination.path) { try fileManager.removeItem(at: destination) }
                try fileManager.copyItem(at: source, to: destination)
            }
        } catch {
            ELOG("Bezels: could not copy \(source.lastPathComponent): \(error)")
            throw ImportProblem.couldNotCopy
        }
        let sidecar = Sidecar(name: name,
                              size: [Double(analysis.size.width), Double(analysis.size.height)],
                              screen: [Double(analysis.screen.minX), Double(analysis.screen.minY),
                                       Double(analysis.screen.width), Double(analysis.screen.height)],
                              system: system, source: kind, listed: listed)
        writeSidecar(sidecar, for: destination)
        guard let bezel = makeBezel(sidecar, imageURL: destination, relativePath: relativePath) else {
            throw ImportProblem.couldNotCopy
        }
        upsert(bezel)
        ILOG("Bezels: added '\(name)' (\(relativePath)), screen \(analysis.screen) of \(analysis.size)")
        return bezel
    }

    // MARK: - Changing

    /// Changes what is kept beside a bezel's image. `nil` leaves a value as it is.
    public func update(id: String, name: String? = nil, system: String?? = nil, listed: Bool? = nil) {
        guard let bezel = bezel(id: id), let image = bezel.image, var sidecar = readSidecar(for: image.fileURL),
              let relativePath = relativePath(of: image.fileURL) else { return }
        if let name, !name.isEmpty { sidecar.name = name }
        if let system { sidecar.system = system }
        if let listed { sidecar.listed = listed }
        writeSidecar(sidecar, for: image.fileURL)
        if let updated = makeBezel(sidecar, imageURL: image.fileURL, relativePath: relativePath) {
            upsert(updated)
        }
    }

    /// Deletes a bezel's image and what is kept beside it.
    public func delete(id: String) {
        guard let image = bezel(id: id)?.image else { return }
        try? FileManager.default.removeItem(at: image.fileURL)
        try? FileManager.default.removeItem(at: sidecarURL(for: image.fileURL))
        mutate { $0.removeAll { $0.id == id } }
    }

    /// Deletes everything under a folder of the library (one repository's downloads).
    public func deleteFolder(relativePath: String) {
        let folder = rootURL.appendingPathComponent(relativePath, isDirectory: true)
        try? FileManager.default.removeItem(at: folder)
        let prefix = Self.idPrefix + relativePath + "/"
        mutate { $0.removeAll { $0.id.hasPrefix(prefix) } }
    }

    /// How many bezels are under a folder of the library, and their size in bytes.
    public func usage(relativePath: String) -> (count: Int, bytes: Int) {
        let prefix = Self.idPrefix + relativePath + "/"
        let files = bezels.filter { $0.id.hasPrefix(prefix) }.compactMap(\.image?.fileURL)
        let bytes = files.reduce(0) { $0 + ((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
        return (files.count, bytes)
    }

    // MARK: - Files

    /// A PNG someone put into `Imported/`: read it once, and remember when it is not a bezel.
    private func adoptDroppedImage(_ url: URL) -> Sidecar? {
        var name = url.deletingPathExtension().lastPathComponent
        var problem: ImportProblem?
        let config = url.deletingPathExtension().appendingPathExtension(Self.configExtension)
        if let text = try? String(contentsOf: config, encoding: .utf8) {
            do {
                if let displayName = try RetroArchOverlayConfig(text: text).displayName { name = displayName }
            } catch RetroArchOverlayConfig.ParseError.touchControls {
                problem = .touchControls
            } catch {
                // No image named: the file adds nothing.
            }
        }
        var sidecar = Sidecar(name: name, size: [0, 0], screen: [0, 0, 0, 0], system: nil, source: .imported, listed: true)
        do {
            if let problem { throw problem }
            let analysis = try TVBezelImage.analyze(url)
            sidecar.size = [Double(analysis.size.width), Double(analysis.size.height)]
            sidecar.screen = [Double(analysis.screen.minX), Double(analysis.screen.minY),
                              Double(analysis.screen.width), Double(analysis.screen.height)]
        } catch {
            let reason = (error as? ImportProblem) ?? ImportProblem(error)
            WLOG("Bezels: \(url.lastPathComponent) is not a bezel: \(reason)")
            sidecar.refusal = String(describing: reason)
        }
        writeSidecar(sidecar, for: url)
        return sidecar
    }

    private func makeBezel(_ sidecar: Sidecar, imageURL: URL, relativePath: String) -> TVBezel? {
        guard sidecar.refusal == nil, sidecar.size.count == 2, sidecar.screen.count == 4,
              sidecar.size[0] > 0, sidecar.size[1] > 0, sidecar.screen[2] > 0, sidecar.screen[3] > 0 else { return nil }
        let image = TVBezel.ImageArtwork(fileURL: imageURL,
                                         size: CGSize(width: sidecar.size[0], height: sidecar.size[1]),
                                         screen: CGRect(x: sidecar.screen[0], y: sidecar.screen[1],
                                                        width: sidecar.screen[2], height: sidecar.screen[3]))
        return TVBezel(id: Self.idPrefix + relativePath, name: sidecar.name, preferredSystems: sidecar.system.map { [$0] } ?? [],
                       image: image, source: sidecar.source, isListed: sidecar.listed)
    }

    private func sidecarURL(for image: URL) -> URL {
        image.deletingLastPathComponent().appendingPathComponent(image.lastPathComponent + Self.sidecarSuffix)
    }

    private func readSidecar(for image: URL) -> Sidecar? {
        guard let data = try? Data(contentsOf: sidecarURL(for: image)) else { return nil }
        return try? JSONDecoder().decode(Sidecar.self, from: data)
    }

    private func writeSidecar(_ sidecar: Sidecar, for image: URL) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            try encoder.encode(sidecar).write(to: sidecarURL(for: image), options: .atomic)
        } catch {
            ELOG("Bezels: could not write \(sidecarURL(for: image).lastPathComponent): \(error)")
        }
    }

    /// `url`'s path inside the folder, with forward slashes.
    private func relativePath(of url: URL) -> String? {
        let root = rootURL.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        guard path.hasPrefix(root + "/") else { return nil }
        return String(path.dropFirst(root.count + 1))
    }

    /// A path in `folder` for `fileName` that no bezel uses yet.
    private func uniqueRelativePath(folder: String, fileName: String) -> String {
        let stem = (fileName as NSString).deletingPathExtension
        var candidate = "\(folder)/\(stem).\(Self.imageExtension)"
        var counter = 2
        while FileManager.default.fileExists(atPath: rootURL.appendingPathComponent(candidate).path) {
            candidate = "\(folder)/\(stem) \(counter).\(Self.imageExtension)"
            counter += 1
        }
        return candidate
    }

    // MARK: - State

    private func upsert(_ bezel: TVBezel) {
        mutate { bezels in
            bezels.removeAll { $0.id == bezel.id }
            bezels.append(bezel)
            bezels.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
    }

    private func replace(with bezels: [TVBezel]) {
        mutate { $0 = bezels }
    }

    private func mutate(_ change: (inout [TVBezel]) -> Void) {
        lock.lock()
        let before = stored
        change(&stored)
        let changed = stored != before
        hasScanned = true
        lock.unlock()
        guard changed else { return }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
        }
    }
}

extension TVBezelLibrary {

    // MARK: - Import

    /// Imports picked files: PNG images, RetroArch overlay `.cfg` files and folders of them.
    /// A `.cfg` gives its image a name, and marks a touch-control overlay, which is refused.
    public func importFiles(at urls: [URL]) -> ImportResult {
        var images: [URL] = []
        var configs: [URL] = []
        var scoped: [URL] = []
        defer { scoped.forEach { $0.stopAccessingSecurityScopedResource() } }
        for url in urls {
            if url.startAccessingSecurityScopedResource() { scoped.append(url) }
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else { continue }
            let files = isDirectory.boolValue
                ? (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
                : [url]
            for file in files {
                switch file.pathExtension.lowercased() {
                case Self.imageExtension: images.append(file)
                case Self.configExtension: configs.append(file)
                default: break
                }
            }
        }

        var result = ImportResult()
        var names: [String: String] = [:]
        var refused: Set<String> = []
        for config in configs {
            guard let text = try? String(contentsOf: config, encoding: .utf8) else { continue }
            do {
                let parsed = try RetroArchOverlayConfig(text: text)
                let key = parsed.imageName.lowercased()
                if let name = parsed.displayName { names[key] = name }
                if !images.contains(where: { $0.lastPathComponent.lowercased() == key }) {
                    result.problems.append((config.lastPathComponent, .missingImage(parsed.imageName)))
                }
            } catch RetroArchOverlayConfig.ParseError.touchControls {
                result.problems.append((config.lastPathComponent, .touchControls))
                // Its images are button art; keep every image the file mentions out.
                for value in RetroArchOverlayConfig.values(in: text).values where value.lowercased().hasSuffix("." + Self.imageExtension) {
                    refused.insert((value as NSString).lastPathComponent.lowercased())
                }
            } catch {
                // A RetroArch file of another kind: nothing in it for a bezel.
                continue
            }
        }
        for image in images where !refused.contains(image.lastPathComponent.lowercased()) {
            do {
                let name = names[image.lastPathComponent.lowercased()] ?? image.deletingPathExtension().lastPathComponent
                let relativePath = uniqueRelativePath(folder: Self.importedFolder, fileName: image.lastPathComponent)
                result.imported.append(try add(imageAt: image, relativePath: relativePath, name: name,
                                               system: nil, source: .imported, listed: true))
            } catch {
                result.problems.append((image.lastPathComponent, ImportProblem(error)))
            }
        }
        return result
    }
}
