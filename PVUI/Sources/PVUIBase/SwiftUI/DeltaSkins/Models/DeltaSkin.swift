import UIKit
import ZIPFoundation
import PVLogging

/// Represents a decoded DeltaSkin file
public struct DeltaSkin: DeltaSkinProtocol {
    /// The decoded info.json contents
    public let info: Info

    /// The URL to the .deltaskin file
    public let fileURL: URL

    /// The raw dictionary from info.json
    private let rawDictionary: [String: Any]

    /// Initialize from either a .deltaskin file or directory
    public init(fileURL: URL) throws {
        self.fileURL = fileURL

        let isDirectory = (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
        DLOG("Loading DeltaSkin from \(fileURL.lastPathComponent) (isDirectory: \(isDirectory))")

        if isDirectory {
            // Load from directory
            let infoURL = fileURL.appendingPathComponent("info.json")
            guard let infoData = try? Data(contentsOf: infoURL) else {
                ELOG("Missing info.json in directory: \(fileURL.path)")
                throw DeltaSkinError.missingInfoFile
            }

            // Store raw dictionary
            guard let jsonObject = try? JSONSerialization.jsonObject(with: infoData),
                  let rawDict = jsonObject as? [String: Any] else {
                throw DeltaSkinError.invalidInfoFile
            }
            self.rawDictionary = rawDict

            let decoder = JSONDecoder()
            let sanitizedData = try sanitizeJSON(infoData)
            self.info = try decoder.decode(Info.self, from: sanitizedData)

        } else {
            // Load from .deltaskin archive
            guard let archive = Archive(url: fileURL, accessMode: .read) else {
                ELOG("Failed to open archive: \(fileURL.path)")
                throw DeltaSkinError.invalidArchive
            }

            guard let infoEntry = archive["info.json"],
                  let infoData = archive.extractData(infoEntry) else {
                ELOG("Failed to extract info.json from archive: \(fileURL.path)")
                throw DeltaSkinError.missingInfoFile
            }

            // Store raw dictionary
            guard let jsonObject = try? JSONSerialization.jsonObject(with: infoData),
                  let rawDict = jsonObject as? [String: Any] else {
                throw DeltaSkinError.invalidInfoFile
            }
            self.rawDictionary = rawDict

            let decoder = JSONDecoder()
            let sanitizedData = try sanitizeJSON(infoData)
            self.info = try decoder.decode(Info.self, from: sanitizedData)
        }

        DLOG("Successfully loaded skin info: \(info.name)")
    }

    // MARK: - DeltaSkinProtocol Conformance

    public var identifier: String { info.identifier }
    public var name: String { info.name }
    public var gameType: DeltaSkinGameType { info.gameTypeIdentifier }
    public var isDebugEnabled: Bool { info.debug }
    /// Keyboard overlay configuration decoded from the skin's `keyboardOverlay` JSON key.
    /// Returns `nil` for skins that do not declare a keyboard overlay.
    public var keyboardOverlay: KeyboardOverlayConfig? { info.keyboardOverlay }

    /// All theme variants bundled in this skin. Empty for legacy skins without themes.
    public var availableThemes: [DeltaSkin.Theme] { info.themes ?? [] }

    /// The currently selected theme ID, persisted per skin in UserDefaults.
    public var selectedThemeId: String? {
        get { DeltaSkinPreferences.shared.selectedThemeId(for: identifier) }
        set { DeltaSkinPreferences.shared.setSelectedThemeId(newValue, for: identifier) }
    }

    public func supports(_ traits: DeltaSkinTraits) -> Bool {
        let result = representation(for: traits) != nil
        ILOG("skins: supports() - device: \(traits.device.rawValue), displayType: \(traits.displayType.rawValue), orientation: \(traits.orientation.rawValue) -> \(result)")
        return result
    }

    public func screens(for traits: DeltaSkinTraits) -> [DeltaSkinScreen]? {
        guard let rep = representation(for: traits),
              let screens = rep.screens else {
            return nil
        }

        return screens.enumerated().map { index, screen in
            DeltaSkinScreen(
                id: "\(identifier)-screen-\(index)",
                inputFrame: screen.inputFrame,
                outputFrame: screen.outputFrame,
                placement: screen.placement ?? .controller,
                filters: screen.filters?.compactMap { filter in
                    let ciFilter = CIFilter(name: filter.name)
                    filter.parameters.forEach { key, value in
                        switch value {
                        case .number(let num):
                            ciFilter?.setValue(num, forKey: key)
                        case .vector(let x, let y):
                            ciFilter?.setValue(CIVector(x: CGFloat(x), y: CGFloat(y)), forKey: key)
                        case .color(let r, let g, let b):
                            ciFilter?.setValue(CIColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b)), forKey: key)
                        case .rectangle(let x, let y, let width, let height):
                            ciFilter?.setValue(CIVector(x: CGFloat(x), y: CGFloat(y), z: CGFloat(width), w: CGFloat(height)), forKey: key)
                        case .affineTransform(let sx, let sy, let tx, let ty, let rot):
                            // Build a CGAffineTransform: T = Translate * Rotate * Scale
                            var t = CGAffineTransform.identity
                            if let sx = sx, let sy = sy {
                                t = t.scaledBy(x: CGFloat(sx), y: CGFloat(sy))
                            }
                            if let rot = rot { t = t.rotated(by: CGFloat(rot)) }
                            if let tx = tx, let ty = ty { t = t.translatedBy(x: CGFloat(tx), y: CGFloat(ty)) }
                            ciFilter?.setValue(NSValue(cgAffineTransform: t), forKey: key)
                        }
                    }
                    return ciFilter
                },
                maintainAspectRatio: screen.maintainAspectRatio
            )
        }
    }

    public func mappingSize(for traits: DeltaSkinTraits) -> CGSize? {
        let rep = representation(for: traits)
        let size = rep?.mappingSize
        if let size = size {
            VLOG("skins: mappingSize() - device: \(traits.device.rawValue), displayType: \(traits.displayType.rawValue), orientation: \(traits.orientation.rawValue) -> \(size)")
        } else {
            ELOG("skins: ERROR - mappingSize() returned nil for traits: \(traits.description)")
        }
        return size
    }

    public func buttons(for traits: DeltaSkinTraits) -> [DeltaSkinButton]? {
        guard let rep = representation(for: traits),
              let items = rep.items else {
            return nil
        }

        return items.enumerated().map { index, item in
            let input: DeltaSkinInput
            switch item.inputs {
            case .single(let inputs):
                input = .single(inputs.first ?? "")
            case .directional(let mapping):
                input = .directional(mapping)
            }

            return DeltaSkinButton(
                id: "\(identifier)-button-\(index)",
                input: input,
                frame: item.frame,
                extendedEdges: item.extendedEdges,
                haptic: item.haptic,
                states: item.states
            )
        }
    }

    public func screenGroups(for traits: DeltaSkinTraits) -> [DeltaSkinScreenGroup]? {
        guard let rep = representation(for: traits),
              let screens = rep.screens else {
            return nil
        }

        return [
            DeltaSkinScreenGroup(
                id: "\(identifier)-screens",
                screens: screens.enumerated().map { index, screen in
                    DeltaSkinScreen(
                        id: "\(identifier)-screen-\(index)",
                        inputFrame: screen.inputFrame,
                        outputFrame: screen.outputFrame,
                        placement: screen.placement ?? .controller,
                        filters: screen.filters?.compactMap { filterInfo in
                            createFilter(from: filterInfo)
                        },
                        maintainAspectRatio: screen.maintainAspectRatio
                    )
                },
                extendedEdges: rep.extendedEdges,
                translucent: rep.translucent ?? false,
                gameScreenFrame: rep.gameScreenFrame
            )
        ]
    }

    /// Returns the `OrientationRepresentations` for the given traits (without converting to RepresentationInfo).
    private func orientationRepresentations(for traits: DeltaSkinTraits) -> OrientationRepresentations? {
        guard let deviceReps = info.representations[traits.device] else { return nil }
        var result: OrientationRepresentations?
        switch traits.displayType {
        case .standard:
            result = deviceReps.standard?[traits.orientation.rawValue]
        case .edgeToEdge:
            result = deviceReps.edgeToEdge?[traits.orientation.rawValue]
            if result == nil { result = deviceReps.standard?[traits.orientation.rawValue] }
        case .splitView:
            result = deviceReps.splitView?[traits.orientation.rawValue]
        case .stageManager:
            result = deviceReps.stageManager?[traits.orientation.rawValue]
        case .externalDisplay:
            result = deviceReps.externalDisplay?[traits.orientation.rawValue]
        }
        if result == nil && traits.displayType == .standard {
            result = deviceReps.edgeToEdge?[traits.orientation.rawValue]
        }
        return result
    }

    /// Returns the animated background configuration for the given traits, if any.
    public func backgroundAnimation(for traits: DeltaSkinTraits) -> DeltaSkinBackgroundAnimation? {
        return orientationRepresentations(for: traits)?.backgroundAnimation
    }

    /// Cached last representation lookup to avoid repeated work/log spam
    private static var lastRepCacheKey: String?
    private static var lastRepCacheValue: DeltaSkin.RepresentationInfo?

    public func representation(for traits: DeltaSkinTraits) -> DeltaSkin.RepresentationInfo? {
        // Fast-path cache: same traits → return cached value without logging
        let cacheKey = "\(traits.device.rawValue)-\(traits.displayType.rawValue)-\(traits.orientation.rawValue)"
        if Self.lastRepCacheKey == cacheKey, let cached = Self.lastRepCacheValue {
            return cached
        }

        VLOG("skins: representation(for:) device=\(traits.device.rawValue) displayType=\(traits.displayType.rawValue) orientation=\(traits.orientation.rawValue)")
        VLOG("skins: Available device reps: \(info.representations.keys.map { $0.rawValue })")

        guard let deviceReps = info.representations[traits.device] else {
            ELOG("skins: ERROR - No representation found for device: \(traits.device.rawValue)")
            ELOG("skins: Available devices: \(info.representations.keys.map { $0.rawValue }.joined(separator: ", "))")
            return nil
        }
            VLOG("skins: Found device representation for: \(traits.device.rawValue)")

        // Log available display types for debugging
        var availableDisplayTypes: [String] = []
        if deviceReps.standard != nil { availableDisplayTypes.append("standard") }
        if deviceReps.edgeToEdge != nil { availableDisplayTypes.append("edgeToEdge") }
        if deviceReps.splitView != nil { availableDisplayTypes.append("splitView") }
        if deviceReps.stageManager != nil { availableDisplayTypes.append("stageManager") }
        if deviceReps.externalDisplay != nil { availableDisplayTypes.append("externalDisplay") }
        VLOG("skins: Available display types for \(traits.device.rawValue): \(availableDisplayTypes.joined(separator: ", "))")

        // Try the requested display type first
        var orientationReps: OrientationRepresentations?
        switch traits.displayType {
        case .standard:
            orientationReps = deviceReps.standard?[traits.orientation.rawValue]
            VLOG("skins: Looking for standard/\(traits.orientation.rawValue) - found: \(orientationReps != nil)")
        case .edgeToEdge:
            orientationReps = deviceReps.edgeToEdge?[traits.orientation.rawValue]
            VLOG("skins: Looking for edgeToEdge/\(traits.orientation.rawValue) - found: \(orientationReps != nil)")
        case .splitView:
            orientationReps = deviceReps.splitView?[traits.orientation.rawValue]
            VLOG("skins: Looking for splitView/\(traits.orientation.rawValue) - found: \(orientationReps != nil)")
        case .stageManager:
            orientationReps = deviceReps.stageManager?[traits.orientation.rawValue]
            VLOG("skins: Looking for stageManager/\(traits.orientation.rawValue) - found: \(orientationReps != nil)")
        case .externalDisplay:
            orientationReps = deviceReps.externalDisplay?[traits.orientation.rawValue]
            VLOG("skins: Looking for externalDisplay/\(traits.orientation.rawValue) - found: \(orientationReps != nil)")
        }

        // If not found and requested display type is edgeToEdge, try standard as fallback
        if orientationReps == nil && traits.displayType == .edgeToEdge {
            VLOG("skins: edgeToEdge not found, trying standard as fallback")
            orientationReps = deviceReps.standard?[traits.orientation.rawValue]
            if orientationReps != nil {
                VLOG("skins: Found standard/\(traits.orientation.rawValue) as fallback")
            }
        }

        // If still not found and requested display type is standard, try edgeToEdge as fallback
        if orientationReps == nil && traits.displayType == .standard {
            VLOG("skins: standard not found, trying edgeToEdge as fallback")
            orientationReps = deviceReps.edgeToEdge?[traits.orientation.rawValue]
            if orientationReps != nil {
                VLOG("skins: Found edgeToEdge/\(traits.orientation.rawValue) as fallback")
            }
        }

        if orientationReps == nil {
            ELOG("skins: ERROR - No orientation representation found for displayType: \(traits.displayType.rawValue), orientation: \(traits.orientation.rawValue), and fallbacks failed")
        }

        let result = orientationReps?.toRepresentationInfo()
        // Store cache
        Self.lastRepCacheKey = cacheKey
        Self.lastRepCacheValue = result
        return result
    }

    /// Cache for decoded images keyed by skin identifier + traits + asset filename
    private static var imageCache: [String: UIImage] = [:]
    private static let imageCacheQueue = DispatchQueue(label: "com.provenance.deltaskin.imagecache", attributes: .concurrent)

    public func image(for traits: DeltaSkinTraits) async throws -> UIImage {
        ILOG("skins: image(for:) called - device: \(traits.device.rawValue), displayType: \(traits.displayType.rawValue), orientation: \(traits.orientation.rawValue)")
        // Get the representation for these traits
        guard let rep = representation(for: traits) else {
            ELOG("skins: ERROR - image(for:) failed: representation returned nil for traits: \(traits.description)")
            throw DeltaSkinError.unsupportedTraits
        }
        ILOG("skins: Got representation, attempting to load image")

        // Check if a theme overrides the asset for this device/displayType/orientation
        var candidates: [String]
        if let themeId = selectedThemeId,
           let theme = availableThemes.first(where: { $0.id == themeId }),
           let themeAsset = theme.assets?[traits.device.rawValue]?[traits.displayType.rawValue]?[traits.orientation.rawValue] {
            // Prepend theme candidates so they are tried first, falling back to base skin
            candidates = themeAsset.candidates() + rep.assets.candidates()
            ILOG("skins: Theme '\(themeId)' override candidates: \(themeAsset.candidates())")
        } else {
            candidates = rep.assets.candidates()
        }
        ILOG("skins: Image candidates: \(candidates)")
        var lastError: Error?
        for name in candidates {
            // Check cache first
            let cacheKey = "\(identifier)-\(traits.device.rawValue)-\(traits.displayType.rawValue)-\(traits.orientation.rawValue)-\(name)"
            if let cachedImage = Self.imageCacheQueue.sync(execute: { Self.imageCache[cacheKey] }) {
                ILOG("skins: Found cached image: \(name)")
                return cachedImage
            }

            ILOG("skins: Attempting to load image asset: \(name)")
            do {
                let data = try loadAssetData(name)
                let lower = name.lowercased()
                let decodedImage: UIImage?
                if lower.hasSuffix(".pdf") {
                    let renderSize: CGSize? = rep.mappingSize.width > 0 && rep.mappingSize.height > 0 ? rep.mappingSize : nil
                    decodedImage = UIImage(pdfData: data, preserveTransparency: rep.translucent ?? false, size: renderSize)
                    if decodedImage == nil {
                        lastError = DeltaSkinError.invalidPDF
                        continue
                    }
                } else {
                    decodedImage = UIImage(data: data, scale: UIScreen.main.scale)
                    if decodedImage == nil {
                        lastError = DeltaSkinError.invalidPNG
                        continue
                    }
                }

                // Cache the decoded image
                if let imageToCache = decodedImage {
                    ILOG("skins: Successfully loaded and decoded image: \(name), size: \(imageToCache.size)")
                    Self.imageCacheQueue.async(flags: .barrier) {
                        Self.imageCache[cacheKey] = imageToCache
                        // Limit cache size to ~50MB (approximately 50 images)
                        if Self.imageCache.count > 50 {
                            // Remove oldest entries (simple FIFO, in production could use LRU)
                            let keysToRemove = Array(Self.imageCache.keys.prefix(10))
                            keysToRemove.forEach { Self.imageCache.removeValue(forKey: $0) }
                        }
                    }
                    return imageToCache
                }
            } catch {
                ELOG("skins: Failed to load asset candidate: \(name) — \(error)")
                lastError = error
                continue
            }
        }

        ELOG("skins: ERROR - Failed to load image after trying all candidates. Last error: \(lastError?.localizedDescription ?? "unknown")")

        // Fallback: try the original filename property (legacy behavior)
        let fallbackName = rep.assets.filename
        let fallbackCacheKey = "\(identifier)-\(traits.device.rawValue)-\(traits.displayType.rawValue)-\(traits.orientation.rawValue)-\(fallbackName)"
        if let cachedImage = Self.imageCacheQueue.sync(execute: { Self.imageCache[fallbackCacheKey] }) {
            return cachedImage
        }

        do {
            let assetData = try loadAssetData(fallbackName)
            let lower = fallbackName.lowercased()
            let decodedImage: UIImage?
            if lower.hasSuffix(".pdf") {
                let renderSize: CGSize? = rep.mappingSize.width > 0 && rep.mappingSize.height > 0 ? rep.mappingSize : nil
                decodedImage = UIImage(pdfData: assetData, preserveTransparency: rep.translucent ?? false, size: renderSize)
                guard decodedImage != nil else {
                    throw DeltaSkinError.invalidPDF
                }
            } else {
                decodedImage = UIImage(data: assetData, scale: UIScreen.main.scale)
                guard decodedImage != nil else {
                    throw DeltaSkinError.invalidPNG
                }
            }

            // Cache the decoded image
            if let imageToCache = decodedImage {
                Self.imageCacheQueue.async(flags: .barrier) {
                    Self.imageCache[fallbackCacheKey] = imageToCache
                    // Limit cache size
                    if Self.imageCache.count > 50 {
                        let keysToRemove = Array(Self.imageCache.keys.prefix(10))
                        keysToRemove.forEach { Self.imageCache.removeValue(forKey: $0) }
                    }
                }
                return imageToCache
            }

            throw lastError ?? DeltaSkinError.invalidPNG
        } catch {
            // Final fallback: if current skin failed, try the manager's default skin for this system
            if let systemId = gameType.systemIdentifier,
               let fallbackSkin = try? await DeltaSkinManager.shared.defaultSkin(for: systemId),
               fallbackSkin.identifier != identifier,
               fallbackSkin.supports(traits) {
                WLOG("skins: Primary skin \(identifier) failed to load asset \(fallbackName); falling back to default skin \(fallbackSkin.identifier)")
                return try await fallbackSkin.image(for: traits)
            }
            throw lastError ?? error
        }
    }

    /// Cache for thumbstick images keyed by skin identifier + filename
    private static var thumbstickImageCache: [String: UIImage] = [:]
    private static let thumbstickCacheQueue = DispatchQueue(label: "com.provenance.deltaskin.thumbstickcache", attributes: .concurrent)

    /// Load the thumbstick image
    func loadThumbstickImage(named: String) async throws -> UIImage {
        // Check cache first
        let cacheKey = "\(identifier)-thumbstick-\(named)"
        if let cachedImage = Self.thumbstickCacheQueue.sync(execute: { Self.thumbstickImageCache[cacheKey] }) {
            return cachedImage
        }

        // Load the asset data
        let assetData = try loadAssetData(named)

        // Create image from PDF data since thumbsticks are PDFs
        let decodedImage: UIImage?
        if named.hasSuffix(".pdf") {
            decodedImage = UIImage(pdfData: assetData, preserveTransparency: true)
            guard decodedImage != nil else {
                throw DeltaSkinError.invalidPDF
            }
        } else {
            // For PNG thumbsticks, ensure we preserve alpha channel
            decodedImage = UIImage(data: assetData)?.imageWithAlpha()
            guard decodedImage != nil else {
                throw DeltaSkinError.invalidPNG
            }
        }

        // Cache the decoded image
        if let imageToCache = decodedImage {
            Self.thumbstickCacheQueue.async(flags: .barrier) {
                Self.thumbstickImageCache[cacheKey] = imageToCache
                // Limit cache size to ~20MB (approximately 40 thumbstick images)
                if Self.thumbstickImageCache.count > 40 {
                    let keysToRemove = Array(Self.thumbstickImageCache.keys.prefix(10))
                    keysToRemove.forEach { Self.thumbstickImageCache.removeValue(forKey: $0) }
                }
            }
            return imageToCache
        }

        throw DeltaSkinError.invalidPNG
    }

    /// A named visual theme variant within a skin file
    public struct Theme: Codable, Identifiable {
        /// Unique identifier for the theme (e.g. "dark", "neon")
        public let id: String
        /// Display name shown in the theme picker
        public let name: String
        /// Per-device asset overrides. Keyed by device rawValue → displayType → orientation → AssetRepresentation.
        /// assets["iphone"]["standard"]["portrait"] = AssetRepresentation
        public let assets: [String: [String: [String: AssetRepresentation]]]?
    }

    /// JSON structure for DeltaSkin info.json
    public struct Info: Codable {
        /// Name displayed in Delta's skin selection menu
        let name: String

        /// Unique identifier in reverse-dns format (e.g. com.yourname.console.skinname)
        let identifier: String

        /// Identifies which system the skin belongs to
        let gameTypeIdentifier: DeltaSkinGameType

        /// Whether to show debug overlay of button mappings. Defaults to false when absent.
        let debug: Bool

        /// Device-specific skin representations
        let representations: Dictionary<DeltaSkinDevice, DeviceRepresentations>

        /// Optional keyboard overlay configuration. When present, a virtual keyboard
        /// overlay will be available for this skin. Old skins that omit this key
        /// fall back gracefully with no keyboard shown.
        let keyboardOverlay: KeyboardOverlayConfig?

        /// Optional list of named visual theme variants bundled in this skin.
        /// Legacy skins that omit this key have no themes (empty array).
        let themes: [Theme]?

        private enum CodingKeys: String, CodingKey {
            case name, identifier, gameTypeIdentifier, debug, representations, keyboardOverlay, themes
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            name = try container.decode(String.self, forKey: .name)
            identifier = try container.decode(String.self, forKey: .identifier)
            gameTypeIdentifier = try container.decode(DeltaSkinGameType.self, forKey: .gameTypeIdentifier)
            debug = try container.decodeIfPresent(Bool.self, forKey: .debug) ?? false

            // Manually decode the dictionary with string keys
            let repContainer = try container.nestedContainer(keyedBy: StringCodingKey.self, forKey: .representations)
            var reps: [DeltaSkinDevice: DeviceRepresentations] = [:]

            for key in repContainer.allKeys {
                if let device = DeltaSkinDevice(rawValue: key.stringValue) {
                    let value = try repContainer.decode(DeviceRepresentations.self, forKey: key)
                    reps[device] = value
                }
            }

            representations = reps
            keyboardOverlay = try container.decodeIfPresent(KeyboardOverlayConfig.self, forKey: .keyboardOverlay)
            themes = try container.decodeIfPresent([Theme].self, forKey: .themes)
        }
    }

    /// Display types for different device modes
    public enum DisplayType: String, Codable {
        case standard
        case edgeToEdge
        case splitView
        case stageManager
        case externalDisplay
    }

    /// Represents device-specific configurations
    public struct DeviceRepresentations: Codable {
        let standard: [String: OrientationRepresentations]?
        let edgeToEdge: [String: OrientationRepresentations]?
        let splitView: [String: OrientationRepresentations]?
        let stageManager: [String: OrientationRepresentations]?
        let externalDisplay: [String: OrientationRepresentations]?
        let mini: [String: OrientationRepresentations]?
        let pro13: [String: OrientationRepresentations]?
        let dedicated: [String: OrientationRepresentations]?

        private enum CodingKeys: String, CodingKey {
            case standard
            case edgeToEdge = "edgeToEdge"
            case splitView = "splitView"
            case stageManager = "stageManager"
            case externalDisplay = "externalDisplay"
            case mini
            case pro13
            case dedicated
        }
    }

    /// Represents orientation-specific configurations
    public struct OrientationRepresentations: Codable {
        /// Assets dictionary for skin images
        let assets: AssetRepresentation?

        /// Button and control mappings
        let items: [ItemRepresentation]?

        /// Screen configurations
        let screens: [ScreenInfo]?

        /// Size in points for mapping coordinates
        let mappingSize: CGSize?

        /// Extended touch edges
        let extendedEdges: UIEdgeInsets?

        /// Whether the skin supports opacity adjustment
        let translucent: Bool?

        /// Frame for the game screen
        let gameScreenFrame: CGRect?

        /// Optional animated background configuration
        let backgroundAnimation: DeltaSkinBackgroundAnimation?

        private enum CodingKeys: String, CodingKey {
            case assets, items, screens, mappingSize, extendedEdges, translucent, gameScreenFrame, backgroundAnimation
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            assets = try container.decodeIfPresent(AssetRepresentation.self, forKey: .assets)
            items = try container.decodeIfPresent([ItemRepresentation].self, forKey: .items)
            screens = try container.decodeIfPresent([ScreenInfo].self, forKey: .screens)

            // Use decodeIfPresent for mappingSize
            if let sizeContainer = try? container.superDecoder(forKey: .mappingSize) {
                mappingSize = try CGSize(fromDeltaSkin: sizeContainer)
            } else {
                mappingSize = nil
            }

            // Handle optional extended edges with more robust null checking
            if container.contains(.extendedEdges),
               let edgeContainer = try? container.superDecoder(forKey: .extendedEdges),
               let edges = try? UIEdgeInsets(fromDeltaSkin: edgeContainer) {
                extendedEdges = edges
            } else {
                extendedEdges = nil
            }

            translucent = try container.decodeIfPresent(Bool.self, forKey: .translucent)

            // Decode gameScreenFrame if present
            if let frameContainer = try? container.superDecoder(forKey: .gameScreenFrame),
               let frame = try? CGRect(fromDeltaSkin: frameContainer) {
                gameScreenFrame = frame
            } else {
                gameScreenFrame = nil
            }

            backgroundAnimation = try container.decodeIfPresent(DeltaSkinBackgroundAnimation.self, forKey: .backgroundAnimation)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(assets, forKey: .assets)
            try container.encodeIfPresent(items, forKey: .items)
            try container.encodeIfPresent(screens, forKey: .screens)
            try mappingSize?.encodeDeltaSkin(to: container.superEncoder(forKey: .mappingSize))
            try container.encodeIfPresent(extendedEdges, forKey: .extendedEdges)
            try container.encodeIfPresent(translucent, forKey: .translucent)

            if let frame = gameScreenFrame {
                try frame.encodeDeltaSkin(to: container.superEncoder(forKey: .gameScreenFrame))
            }

            try container.encodeIfPresent(backgroundAnimation, forKey: .backgroundAnimation)
        }

        /// Convert to RepresentationInfo
        func toRepresentationInfo() -> DeltaSkin.RepresentationInfo {
            // Create a default asset representation if none exists
            let defaultAssets = DeltaSkin.AssetRepresentation(
                resizable: nil,
                small: nil,
                medium: nil,
                large: nil
            )

            // Validate assets
            if let assets = assets {
                // Allow both PDF and PNG for resizable assets
                if let resizable = assets.resizable,
                   !resizable.hasSuffix(".pdf") && !resizable.hasSuffix(".png") {
                    ELOG("Resizable asset must be a PDF or PNG file")
                    return DeltaSkin.RepresentationInfo(
                        assets: defaultAssets,
                        mappingSize: mappingSize ?? CGSize(width: 0, height: 0),
                        translucent: translucent,
                        screens: screens,
                        items: items,
                        extendedEdges: extendedEdges,
                        gameScreenFrame: gameScreenFrame
                    )
                }
            }

            return DeltaSkin.RepresentationInfo(
                assets: assets ?? defaultAssets,
                mappingSize: mappingSize ?? CGSize(width: 0, height: 0),
                translucent: translucent,
                screens: screens,
                items: items,
                extendedEdges: extendedEdges,
                gameScreenFrame: gameScreenFrame
            )
        }
    }

    /// Asset representation in a skin
    public struct AssetRepresentation: Codable {
        /// Resizable PDF or PNG asset filename
        public let resizable: String?

        /// Size-specific PNG asset filenames
        public let small: String?
        public let medium: String?
        public let large: String?

        /// Get filename for a specific size
        func filename(for size: DeltaSkinAssetSize) -> String? {
            switch size {
            case .resizable: return resizable
            case .small: return small
            case .medium: return medium
            case .large: return large
            }
        }

        /// Candidate filenames in priority order, de-duplicated
        func candidates() -> [String] {
            var list: [String] = []
            if let r = resizable { list.append(r) }
            if let l = large { list.append(l) }
            if let m = medium { list.append(m) }
            if let s = small { list.append(s) }
            // De-duplicate while preserving order
            var seen = Set<String>()
            return list.filter { seen.insert($0).inserted }
        }

        /// The filename to use for this asset
        var filename: String {
            // Try resizable first
            if let resizable = resizable {
                return resizable
            }

            // Fall back to largest available size
            if let large = large {
                return large
            }
            if let medium = medium {
                return medium
            }
            if let small = small {
                return small
            }

            // If we get here, something's wrong with the skin
            fatalError("Invalid asset configuration")
        }

        private enum CodingKeys: String, CodingKey {
            case resizable, small, medium, large
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            // Decode optional fields and sanitize empty/whitespace values to nil
            func clean(_ s: String?) -> String? {
                guard let t = s?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return nil }
                return t
            }
            let rawResizable = try container.decodeIfPresent(String.self, forKey: .resizable)
            let rawSmall = try container.decodeIfPresent(String.self, forKey: .small)
            let rawMedium = try container.decodeIfPresent(String.self, forKey: .medium)
            let rawLarge = try container.decodeIfPresent(String.self, forKey: .large)

            resizable = clean(rawResizable)
            small = clean(rawSmall)
            medium = clean(rawMedium)
            large = clean(rawLarge)

            // Do not hard-fail on missing or invalid asset names here.
            // Validation and fallbacks are handled in toRepresentationInfo().
        }

        init(resizable: String?, small: String?, medium: String?, large: String?) {
            self.resizable = resizable
            self.small = small
            self.medium = medium
            self.large = large
        }
    }

    /// Represents a button or control mapping
    public struct ItemRepresentation: Codable {
        /// Input mappings (single, multiple, or directional)
        let inputs: InputType

        /// Frame rectangle in points
        let frame: CGRect

        /// Extended touch edges
        let extendedEdges: UIEdgeInsets?

        /// Optional thumbstick configuration
        let thumbstick: ThumbstickConfig?

        /// Optional per-button haptic feedback configuration
        let haptic: DeltaSkinHaptic?

        /// Optional per-button visual states (normal/pressed images, animated frames)
        let states: DeltaSkinButtonStates?

        private enum CodingKeys: String, CodingKey {
            case inputs, frame, extendedEdges, thumbstick, haptic, states
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            inputs = try container.decode(InputType.self, forKey: .inputs)
            frame = try CGRect(fromDeltaSkin: container.superDecoder(forKey: .frame))

            // Handle optional extended edges with direct dictionary decoding
            if container.contains(.extendedEdges),
               let edgeContainer = try? container.nestedContainer(keyedBy: DeltaSkinCodingKeys.self, forKey: .extendedEdges) {
                let top = try edgeContainer.decodeIfPresent(CGFloat.self, forKey: .top) ?? 0
                let left = try edgeContainer.decodeIfPresent(CGFloat.self, forKey: .left) ?? 0
                let bottom = try edgeContainer.decodeIfPresent(CGFloat.self, forKey: .bottom) ?? 0
                let right = try edgeContainer.decodeIfPresent(CGFloat.self, forKey: .right) ?? 0
                extendedEdges = UIEdgeInsets(top: top, left: left, bottom: bottom, right: right)
            } else {
                extendedEdges = nil
            }

            thumbstick = try container.decodeIfPresent(ThumbstickConfig.self, forKey: .thumbstick)
            haptic = try container.decodeIfPresent(DeltaSkinHaptic.self, forKey: .haptic)
            states = try container.decodeIfPresent(DeltaSkinButtonStates.self, forKey: .states)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(inputs, forKey: .inputs)
            try frame.encodeDeltaSkin(to: container.superEncoder(forKey: .frame))

            if let edges = extendedEdges {
                try edges.encodeDeltaSkin(to: container.superEncoder(forKey: .extendedEdges))
            }

            try container.encodeIfPresent(thumbstick, forKey: .thumbstick)
            try container.encodeIfPresent(haptic, forKey: .haptic)
            try container.encodeIfPresent(states, forKey: .states)
        }
    }

    /// Represents different types of input configurations
    public enum InputType: Codable {
        case single([String])          // ["a"]
        case directional([String: String])  // {"up": "up", "down": "down"}

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()

            if let array = try? container.decode([String].self) {
                self = .single(array)
            } else if let dict = try? container.decode([String: String].self) {
                self = .directional(dict)
            } else {
                throw DecodingError.typeMismatch(
                    InputType.self,
                    DecodingError.Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "Expected either array of strings or directional mapping"
                    )
                )
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .single(let array):
                try container.encode(array)
            case .directional(let dict):
                try container.encode(dict)
            }
        }
    }

    /// Configuration for thumbstick controls
    public struct ThumbstickConfig: Codable {
        let name: String
        let width: CGFloat
        let height: CGFloat
    }

    /// Screen configuration and filters
    public struct ScreenInfo: Codable {
        let inputFrame: CGRect?
        let outputFrame: CGRect?
        let placement: DeltaSkinScreenPlacement?
        let filters: [FilterInfo]?
        /// When `true` (default) the emulator viewport should maintain the system's
        /// native pixel aspect ratio rather than stretching to fill `outputFrame`.
        let maintainAspectRatio: Bool

        private enum CodingKeys: String, CodingKey {
            case inputFrame, outputFrame, placement, filters, maintainAspectRatio
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            // Decode inputFrame if present
            if let inputContainer = try? container.nestedContainer(keyedBy: DeltaSkinCodingKeys.self, forKey: .inputFrame) {
                let x = try inputContainer.decode(CGFloat.self, forKey: .x)
                let y = try inputContainer.decode(CGFloat.self, forKey: .y)
                let width = try inputContainer.decode(CGFloat.self, forKey: .width)
                let height = try inputContainer.decode(CGFloat.self, forKey: .height)
                inputFrame = CGRect(x: x, y: y, width: width, height: height)
            } else {
                inputFrame = nil
            }

            // Decode optional outputFrame
            if let outputContainer = try? container.nestedContainer(keyedBy: DeltaSkinCodingKeys.self, forKey: .outputFrame) {
                let x = try outputContainer.decode(CGFloat.self, forKey: .x)
                let y = try outputContainer.decode(CGFloat.self, forKey: .y)
                let width = try outputContainer.decode(CGFloat.self, forKey: .width)
                let height = try outputContainer.decode(CGFloat.self, forKey: .height)
                outputFrame = CGRect(x: x, y: y, width: width, height: height)
            } else {
                outputFrame = nil
            }

            // Decode optional fields
            placement = try container.decodeIfPresent(DeltaSkinScreenPlacement.self, forKey: .placement)
            filters = try container.decodeIfPresent([FilterInfo].self, forKey: .filters)
            maintainAspectRatio = try container.decodeIfPresent(Bool.self, forKey: .maintainAspectRatio) ?? true
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            // Encode inputFrame if present
            if let inputFrame = inputFrame {
                var inputContainer = container.nestedContainer(keyedBy: DeltaSkinCodingKeys.self, forKey: .inputFrame)
                try inputContainer.encode(inputFrame.origin.x, forKey: .x)
                try inputContainer.encode(inputFrame.origin.y, forKey: .y)
                try inputContainer.encode(inputFrame.size.width, forKey: .width)
                try inputContainer.encode(inputFrame.size.height, forKey: .height)
            }

            // Encode optional outputFrame
            if let frame = outputFrame {
                var outputContainer = container.nestedContainer(keyedBy: DeltaSkinCodingKeys.self, forKey: .outputFrame)
                try outputContainer.encode(frame.origin.x, forKey: .x)
                try outputContainer.encode(frame.origin.y, forKey: .y)
                try outputContainer.encode(frame.size.width, forKey: .width)
                try outputContainer.encode(frame.size.height, forKey: .height)
            }

            // Encode optional fields
            try container.encodeIfPresent(placement, forKey: .placement)
            try container.encodeIfPresent(filters, forKey: .filters)
            try container.encode(maintainAspectRatio, forKey: .maintainAspectRatio)
        }
    }

    /// CoreImage filter configuration
    public struct FilterInfo: Codable {
        public let name: String
        public let parameters: [String: FilterParameter]

        public init(name: String, parameters: [String: FilterParameter] = [:]) {
            self.name = name
            self.parameters = parameters
        }

        private enum CodingKeys: String, CodingKey {
            case name, parameters
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decode(String.self, forKey: .name)
            let rawParameters = try container.decodeIfPresent([String: FilterParameter].self, forKey: .parameters) ?? [:]

            // Sanitize parameters during decoding
            if name == "CIGaussianBlur" {
                parameters = rawParameters.filter { key, _ in
                    key == "inputRadius"
                }
            } else {
                parameters = rawParameters
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(name, forKey: .name)
            try container.encode(parameters, forKey: .parameters)
        }
    }

    /// Add this to the DeltaSkin struct
    public struct RepresentationInfo: Codable {
        /// Assets for this representation
        public let assets: AssetRepresentation

        /// Size in points for mapping coordinates
        public let mappingSize: CGSize

        /// Whether the skin supports opacity adjustment
        public let translucent: Bool?

        /// Screen configurations
        public let screens: [ScreenInfo]?

        /// Button and control mappings
        public let items: [ItemRepresentation]?

        /// Extended touch edges
        public let extendedEdges: UIEdgeInsets?

        /// Frame for the game screen
        public let gameScreenFrame: CGRect?

        public init(assets: AssetRepresentation, mappingSize: CGSize = .zero, translucent: Bool? = nil, screens: [ScreenInfo]? = nil, items: [ItemRepresentation]? = nil, extendedEdges: UIEdgeInsets? = nil, gameScreenFrame: CGRect? = nil) {
            self.assets = assets
            self.mappingSize = mappingSize
            self.translucent = translucent
            self.screens = screens
            self.items = items
            self.extendedEdges = extendedEdges
            self.gameScreenFrame = gameScreenFrame
        }
    }

    public var jsonRepresentation: [String: Any] {
        return rawDictionary
    }

    /// Convert representation info into button group
    func toButtonGroup(from rep: RepresentationInfo) -> DeltaSkinButtonGroup {
        let buttons = rep.items?.map { item -> DeltaSkinButton in
            // Convert input type
            let input: DeltaSkinInput
            switch item.inputs {
            case .single(let inputs):
                // Use first input as primary if multiple exist
                input = .single(inputs[0])
            case .directional(let mapping):
                input = .directional(mapping)
            }

            // Create unique ID from input
            let id: String
            switch input {
            case .single(let name): id = name
            case .directional: id = "dpad"
            }

            return DeltaSkinButton(
                id: id,
                input: input,
                frame: item.frame,
                extendedEdges: item.extendedEdges,
                haptic: item.haptic,
                states: item.states
            )
        } ?? []

        return DeltaSkinButtonGroup(
            buttons: buttons,
            extendedEdges: rep.extendedEdges,
            translucent: rep.translucent
        )
    }

    /// Safely sanitizes filter parameters for known problematic filters
    private func sanitizeFilterParameters(_ filterInfo: FilterInfo) -> [String: FilterParameter] {
        var parameters = filterInfo.parameters

        // Handle CIGaussianBlur - only allow inputRadius
        if filterInfo.name == "CIGaussianBlur" {
            parameters = parameters.filter { key, _ in
                key == "inputRadius"
            }
        }

        return parameters
    }

    private func createFilter(from filterInfo: FilterInfo) -> CIFilter? {
        // Use custom screen filter for special effects
        if let screenFilter = DeltaSkinScreenFilter(filterInfo: filterInfo) {
            return screenFilter.filter
        }
        return nil
    }
}

/// Helper for string-keyed coding keys
private struct StringCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        return nil
    }
}

// MARK: - Error Types
public enum DeltaSkinError: Error {
    case invalidArchive
    case missingInfoFile
    case invalidInfoFile
    case unsupportedTraits
    case missingAsset
    case missingAssetFile
    case invalidPDF
    case invalidPNG
    case invalidAssetSize
    case invalidScreenConfiguration
    case invalidButtonConfiguration
    case accessDenied
    case notFound
    case deletionNotAllowed
}

extension Archive {
    func extractData(_ entry: Entry) -> Data? {
        var data = Data()
        do {
            _ = try self.extract(entry) { chunk in
                data.append(chunk)
            }
            return data
        } catch {
            return nil
        }
    }
}

private func sanitizeJSON(_ data: Data) throws -> Data {
    guard let jsonString = String(data: data, encoding: .utf8) else {
        throw DeltaSkinError.invalidInfoFile
    }

    // Remove single line comments and handle special fields
    var lines = jsonString.components(separatedBy: .newlines)
    lines = lines.map { line in
        var line = line

        // Handle special comment fields that are valid JSON
        if line.contains("\"_comment\"") {
            return line
        }

        // Remove standard comments
        if let commentIndex = line.range(of: "//")?.lowerBound {
            line = String(line[..<commentIndex])
        }

        return line.trimmingCharacters(in: .whitespaces)
    }
    .filter { !$0.isEmpty }

    // Rejoin and convert back to data
    let sanitized = lines.joined(separator: "\n")
    guard let sanitizedData = sanitized.data(using: .utf8) else {
        throw DeltaSkinError.invalidInfoFile
    }

    return sanitizedData
}

// Fix the UIImage PDF initialization
extension UIImage {
    /// Render a PDF data blob into a UIImage.
    ///
    /// - Parameters:
    ///   - pdfData: Raw PDF file data.
    ///   - preserveTransparency: When `true` the canvas is pre-filled with a transparent background.
    ///     When `false` the canvas is pre-filled with an opaque black background.
    ///   - size: Optional target logical size (points).  When provided the canvas is exactly that size;
    ///     PDF content is aspect-fitted within the canvas (preserving its aspect ratio) and centred.
    ///     When `nil` the native PDF page size is used, capped at 4096 physical pixels to stay within
    ///     safe GPU texture limits.
    convenience init?(pdfData: Data, preserveTransparency: Bool = false, size: CGSize? = nil) {
        guard let provider = CGDataProvider(data: pdfData as CFData),
              let pdf = CGPDFDocument(provider),
              let page = pdf.page(at: 1) else {
            return nil
        }

        let pageRect = page.getBoxRect(.mediaBox)

        let finalSize: CGSize
        let scale: CGFloat

        if let requestedSize = size, requestedSize.width > 0, requestedSize.height > 0 {
            // Caller supplied an explicit target size – render at that size, capped for safety.
            let maxDimension: CGFloat = 4096
            let capScale = min(
                maxDimension / requestedSize.width,
                maxDimension / requestedSize.height,
                1.0
            )
            let cappedSize = CGSize(
                width: requestedSize.width * capScale,
                height: requestedSize.height * capScale
            )
            finalSize = cappedSize
            scale = min(cappedSize.width / pageRect.width,
                        cappedSize.height / pageRect.height)
        } else {
            // No explicit size – use native PDF dimensions, capped at 4096 physical pixels.
            // The cap must be in points (not pixels) since UIGraphicsImageRenderer works in points
            // and will apply the renderer scale when rasterizing.
            let rendererScale = UIScreen.main.scale
            let maxPoints: CGFloat = 4096 / rendererScale
            let capScale = min(
                maxPoints / pageRect.width,
                maxPoints / pageRect.height,
                1.0 // Don't scale up, only down
            )
            scale = capScale
            finalSize = CGSize(
                width: pageRect.width * scale,
                height: pageRect.height * scale
            )
        }

        let renderer = UIGraphicsImageRenderer(
            size: finalSize,
            format: {
                let format = UIGraphicsImageRendererFormat()
                format.scale = UIScreen.main.scale
                format.opaque = !preserveTransparency // Opaque when not preserving transparency
                return format
            }()
        )

        let image = renderer.image { context in
            // Fill background based on preserveTransparency flag
            if preserveTransparency {
                UIColor.clear.setFill()
            } else {
                UIColor.black.setFill()
            }
            context.fill(CGRect(origin: .zero, size: finalSize))

            // Draw PDF with aspect-fit scaling, centred within the canvas.
            // When a requested size is given and its aspect ratio differs from the PDF,
            // centre the scaled PDF so transparent (or opaque) padding is evenly distributed.
            let scaledWidth = pageRect.width * scale
            let scaledHeight = pageRect.height * scale
            let xOffset = (finalSize.width - scaledWidth) / 2
            let yOffset = (finalSize.height - scaledHeight) / 2
            context.cgContext.translateBy(x: xOffset, y: yOffset + scaledHeight)
            context.cgContext.scaleBy(x: scale, y: -scale)
            context.cgContext.drawPDFPage(page)
        }

        self.init(cgImage: image.cgImage!)
    }
}

// Add extension for UIImage to ensure alpha channel
private extension UIImage {
    func imageWithAlpha() -> UIImage {
        // If image already has alpha, return as is
        if hasAlpha {
            return self
        }

        // Create new image with alpha channel
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            draw(at: .zero)
        }
    }

    var hasAlpha: Bool {
        guard let cgImage = cgImage else { return false }
        let alpha = cgImage.alphaInfo
        return alpha == .first || alpha == .last || alpha == .premultipliedFirst || alpha == .premultipliedLast
    }
}

/// Asset size options for Delta skins
public enum DeltaSkinAssetSize: String {
    case small
    case medium
    case large
    case resizable
}
