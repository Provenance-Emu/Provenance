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

    public func supports(_ traits: DeltaSkinTraits) -> Bool {
        representation(for: traits) != nil
    }
    
    /// Check if this skin supports a specific device, regardless of orientation or display type
    /// - Parameter device: The device to check support for
    /// - Returns: True if the skin supports the device in any orientation or display type
    public func supports(_ device: DeltaSkinDevice) -> Bool {
        // Check if we have any representations for this device
        DLOG("Checking if skin '\(name)' supports device '\(device.rawValue)'")
        
        // First check if the device is directly in the representations dictionary
        if info.representations[device] != nil {
            DLOG("✅ Skin '\(name)' has direct representation for '\(device.rawValue)'")
            return true
        }
        
        // If not found directly, check using case-insensitive matching
        for (deviceKey, _) in info.representations {
            if deviceKey == device {
                DLOG("✅ Skin '\(name)' supports '\(device.rawValue)' via case-insensitive match with '\(deviceKey)'")
                return true
            }
        }
        
        // Also check the raw JSON representation for more flexibility
        if let jsonRep = jsonRepresentation["representations"] as? [String: Any] {
            for (key, value) in jsonRep {
                // Try to match the key to our device type
                if let matchedDevice = DeltaSkinDevice.fromString(key), 
                   matchedDevice == device,
                   let deviceRep = value as? [String: Any], 
                   !deviceRep.isEmpty {
                    DLOG("✅ Skin '\(name)' supports '\(device.rawValue)' via JSON representation with key '\(key)'")
                    return true
                }
            }
        }
        
        DLOG("❌ Skin '\(name)' does not support device '\(device.rawValue)'")
        return false
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
                        }
                    }
                    return ciFilter
                }
            )
        }
    }

    public func mappingSize(for traits: DeltaSkinTraits) -> CGSize? {
        representation(for: traits)?.mappingSize
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
                extendedEdges: item.extendedEdges
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
                        }
                    )
                },
                extendedEdges: rep.extendedEdges,
                translucent: rep.translucent ?? false,
                gameScreenFrame: rep.gameScreenFrame
            )
        ]
    }

    public func representation(for traits: DeltaSkinTraits) -> DeltaSkin.RepresentationInfo? {
        // First try direct lookup using the enum value
        if let deviceReps = info.representations[traits.device] {
            let orientationReps: OrientationRepresentations?
            switch traits.displayType {
            case .standard:
                // Try to find the orientation representation using case-insensitive matching
                if let standardDict = deviceReps.standard {
                    // First try direct lookup
                    if let directMatch = standardDict[traits.orientation.rawValue] {
                        return directMatch.toRepresentationInfo()
                    }
                    
                    // If direct lookup fails, try case-insensitive matching
                    for (key, value) in standardDict {
                        if key.lowercased() == traits.orientation.rawValue.lowercased() {
                            DLOG("Found orientation \(traits.orientation.rawValue) using case-insensitive match with key \(key)")
                            return value.toRepresentationInfo()
                        }
                    }
                }
                orientationReps = nil
            case .edgeToEdge:
                orientationReps = deviceReps.edgeToEdge?[traits.orientation.rawValue]
            case .splitView:
                orientationReps = deviceReps.splitView?[traits.orientation.rawValue]
            case .stageManager:
                orientationReps = deviceReps.stageManager?[traits.orientation.rawValue]
            case .externalDisplay:
                orientationReps = deviceReps.externalDisplay?[traits.orientation.rawValue]
            }
            
            return orientationReps?.toRepresentationInfo()
        }
        
        // If direct lookup fails, try case-insensitive matching for device
        DLOG("Direct device lookup failed, trying case-insensitive matching for \(traits.device.rawValue)")
        for (deviceKey, deviceReps) in info.representations {
            // Try to match the device key using our helper method
            if let matchedDevice = DeltaSkinDevice.fromString(deviceKey.rawValue), 
               matchedDevice == traits.device {
                DLOG("Found device \(traits.device.rawValue) using case-insensitive match with key \(deviceKey)")
                
                // Now try to find the orientation representation
                let orientationReps: OrientationRepresentations?
                switch traits.displayType {
                case .standard:
                    // Try to find the orientation representation using case-insensitive matching
                    if let standardDict = deviceReps.standard {
                        // First try direct lookup
                        if let directMatch = standardDict[traits.orientation.rawValue] {
                            return directMatch.toRepresentationInfo()
                        }
                        
                        // If direct lookup fails, try case-insensitive matching
                        for (key, value) in standardDict {
                            if let matchedOrientation = DeltaSkinOrientation.fromString(key),
                               matchedOrientation == traits.orientation {
                                DLOG("Found orientation \(traits.orientation.rawValue) using case-insensitive match with key \(key)")
                                return value.toRepresentationInfo()
                            }
                        }
                    }
                    orientationReps = nil
                case .edgeToEdge:
                    orientationReps = deviceReps.edgeToEdge?[traits.orientation.rawValue]
                case .splitView:
                    orientationReps = deviceReps.splitView?[traits.orientation.rawValue]
                case .stageManager:
                    orientationReps = deviceReps.stageManager?[traits.orientation.rawValue]
                case .externalDisplay:
                    orientationReps = deviceReps.externalDisplay?[traits.orientation.rawValue]
                }
                
                return orientationReps?.toRepresentationInfo()
            }
        }
        
        return nil
    }

    public func image(for traits: DeltaSkinTraits) async throws -> UIImage {
        // Get the representation for these traits
        guard let rep = representation(for: traits) else {
            throw DeltaSkinError.unsupportedTraits
        }

        // Load the asset data
        let assetData = try loadAssetData(rep.assets.filename)
        let preserveTransparency = rep.translucent ?? false

        // Create image from data
        if rep.assets.filename.hasSuffix(".pdf") {
            guard let image = UIImage(pdfData: assetData, preserveTransparency: preserveTransparency) else {
                throw DeltaSkinError.invalidPDF
            }
            return image
        } else {
            guard let image = UIImage(data: assetData, scale: UIScreen.main.scale) else {
                throw DeltaSkinError.invalidPNG
            }
            return image
        }
    }

    /// Load the thumbstick image
    func loadThumbstickImage(named: String) async throws -> UIImage {
        // Load the asset data
        let assetData = try loadAssetData(named)

        // Create image from PDF data since thumbsticks are PDFs
        if named.hasSuffix(".pdf") {
            guard let image = UIImage(pdfData: assetData, preserveTransparency: true) else {
                throw DeltaSkinError.invalidPDF
            }
            return image
        } else {
            // For PNG thumbsticks, ensure we preserve alpha channel
            guard let image = UIImage(data: assetData)?.imageWithAlpha() else {
                throw DeltaSkinError.invalidPNG
            }
            return image
        }
    }

    /// JSON structure for DeltaSkin info.json
    public struct Info: Codable {
        /// Name displayed in Delta's skin selection menu
        let name: String

        /// Unique identifier in reverse-dns format (e.g. com.yourname.console.skinname)
        let identifier: String

        /// Identifies which system the skin belongs to
        let gameTypeIdentifier: DeltaSkinGameType

        /// Whether to show debug overlay of button mappings
        let debug: Bool

        /// Device-specific skin representations
        let representations: Dictionary<DeltaSkinDevice, DeviceRepresentations>

        private enum CodingKeys: String, CodingKey {
            case name, identifier, gameTypeIdentifier, debug, representations
        }
        
        public init(name: String, identifier: String, gameTypeIdentifier: DeltaSkinGameType, debug: Bool, representations: Dictionary<DeltaSkinDevice, DeviceRepresentations>) {
            self.name = name
            self.identifier = identifier
            self.gameTypeIdentifier = gameTypeIdentifier
            self.debug = debug
            self.representations = representations
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            name = try container.decode(String.self, forKey: .name)
            identifier = try container.decode(String.self, forKey: .identifier)
            gameTypeIdentifier = try container.decode(DeltaSkinGameType.self, forKey: .gameTypeIdentifier)
            debug = try container.decode(Bool.self, forKey: .debug)

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
        
        public init(standard: [String : OrientationRepresentations]? = nil, edgeToEdge: [String : OrientationRepresentations]? = nil, splitView: [String : OrientationRepresentations]? = nil, stageManager: [String : OrientationRepresentations]? = nil, externalDisplay: [String : OrientationRepresentations]? = nil, mini: [String : OrientationRepresentations]? = nil, pro13: [String : OrientationRepresentations]? = nil, dedicated: [String : OrientationRepresentations]? = nil) {
            self.standard = standard
            self.edgeToEdge = edgeToEdge
            self.splitView = splitView
            self.stageManager = stageManager
            self.externalDisplay = externalDisplay
            self.mini = mini
            self.pro13 = pro13
            self.dedicated = dedicated
        }

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

        private enum CodingKeys: String, CodingKey {
            case assets, items, screens, mappingSize, extendedEdges, translucent, gameScreenFrame
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

            // Decode optional fields
            resizable = try container.decodeIfPresent(String.self, forKey: .resizable)
            small = try container.decodeIfPresent(String.self, forKey: .small)
            medium = try container.decodeIfPresent(String.self, forKey: .medium)
            large = try container.decodeIfPresent(String.self, forKey: .large)

            // Validate that we have at least one asset
            if resizable == nil && small == nil && medium == nil && large == nil {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "Asset must have at least one size"
                    )
                )
            }

            // If resizable is present, ensure it's a PDF or PNG
            if let resizable = resizable,
               !resizable.hasSuffix(".pdf") && !resizable.hasSuffix(".png") {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "Resizable asset must be a PDF or PNG file"
                    )
                )
            }

            // If size-specific assets are present, ensure they're PNGs
            let pngAssets = [small, medium, large].compactMap { $0 }
            if !pngAssets.isEmpty && !pngAssets.allSatisfy({ $0.hasSuffix(".png") }) {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "Size-specific assets must be PNG files"
                    )
                )
            }
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

        private enum CodingKeys: String, CodingKey {
            case inputs, frame, extendedEdges, thumbstick
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
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(inputs, forKey: .inputs)
            try frame.encodeDeltaSkin(to: container.superEncoder(forKey: .frame))

            if let edges = extendedEdges {
                try edges.encodeDeltaSkin(to: container.superEncoder(forKey: .extendedEdges))
            }

            try container.encodeIfPresent(thumbstick, forKey: .thumbstick)
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
        let outputFrame: CGRect
        let placement: DeltaSkinScreenPlacement?
        let filters: [FilterInfo]?

        private enum CodingKeys: String, CodingKey {
            case inputFrame, outputFrame, placement, filters
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

            // Decode required outputFrame
            let outputContainer = try container.nestedContainer(keyedBy: DeltaSkinCodingKeys.self, forKey: .outputFrame)
            let x = try outputContainer.decode(CGFloat.self, forKey: .x)
            let y = try outputContainer.decode(CGFloat.self, forKey: .y)
            let width = try outputContainer.decode(CGFloat.self, forKey: .width)
            let height = try outputContainer.decode(CGFloat.self, forKey: .height)
            outputFrame = CGRect(x: x, y: y, width: width, height: height)

            // Decode optional fields
            placement = try container.decodeIfPresent(DeltaSkinScreenPlacement.self, forKey: .placement)
            filters = try container.decodeIfPresent([FilterInfo].self, forKey: .filters)
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

            // Encode required outputFrame
            var outputContainer = container.nestedContainer(keyedBy: DeltaSkinCodingKeys.self, forKey: .outputFrame)
            try outputContainer.encode(outputFrame.origin.x, forKey: .x)
            try outputContainer.encode(outputFrame.origin.y, forKey: .y)
            try outputContainer.encode(outputFrame.size.width, forKey: .width)
            try outputContainer.encode(outputFrame.size.height, forKey: .height)

            // Encode optional fields
            try container.encodeIfPresent(placement, forKey: .placement)
            try container.encodeIfPresent(filters, forKey: .filters)
        }
    }

    /// CoreImage filter configuration
    public struct FilterInfo: Codable {
        let name: String
        let parameters: [String: FilterParameter]

        private enum CodingKeys: String, CodingKey {
            case name, parameters
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decode(String.self, forKey: .name)
            let rawParameters = try container.decode([String: FilterParameter].self, forKey: .parameters)

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
                extendedEdges: item.extendedEdges
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
    convenience init?(pdfData: Data, preserveTransparency: Bool = false) {
        guard let provider = CGDataProvider(data: pdfData as CFData),
              let pdf = CGPDFDocument(provider),
              let page = pdf.page(at: 1) else {
            return nil
        }

        let pageRect = page.getBoxRect(.mediaBox)

        // Add size validation and scaling
        let maxDimension: CGFloat = 4096 // Maximum safe texture size
        let scale = min(
            maxDimension / pageRect.width,
            maxDimension / pageRect.height,
            1.0 // Don't scale up, only down
        )

        let finalSize = CGSize(
            width: pageRect.width * scale,
            height: pageRect.height * scale
        )

        let renderer = UIGraphicsImageRenderer(
            size: finalSize,
            format: {
                let format = UIGraphicsImageRendererFormat()
                format.scale = UIScreen.main.scale
                format.opaque = false // Never opaque for joysticks
                return format
            }()
        )

        let image = renderer.image { context in
            // Always fill with clear for joysticks
            UIColor.clear.setFill()
            context.fill(CGRect(origin: .zero, size: finalSize))

            // Draw PDF with scaling
            context.cgContext.scaleBy(x: scale, y: scale)
            context.cgContext.translateBy(x: 0, y: pageRect.height)
            context.cgContext.scaleBy(x: 1.0, y: -1.0)
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
