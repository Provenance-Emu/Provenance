//
//  ControllerSkin.swift
//  DeltaCore
//
//  Created by Riley Testut on 5/5/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import UIKit

#if FRAMEWORK || STATIC_LIBRARY || SWIFT_PACKAGE
import ZIPFoundation
#endif

public let kUTTypeDeltaControllerSkin: CFString = "com.rileytestut.delta.skin" as CFString

private typealias RepresentationDictionary = [String: [String: AnyObject]]

public extension GameControllerInputType
{
    static let controllerSkin = GameControllerInputType("controllerSkin")
}

private extension Archive
{
    func extract(_ entry: Entry) throws -> Data
    {
        var data = Data()
        _ = try self.extract(entry) { data.append($0) }
        
        return data
    }
}

extension ControllerSkin
{
    public struct Screen
    {
        public var inputFrame: CGRect?
        public var outputFrame: CGRect
        
        public var filters: [CIFilter]?
    }
}

public struct ControllerSkin: ControllerSkinProtocol
{
    public let name: String
    public let identifier: String
    public let gameType: GameType
    public let isDebugModeEnabled: Bool
    
    public let fileURL: URL
    
    private let representations: [Traits: Representation]
    private let imageCache = NSCache<NSString, UIImage>()
    
    private let archive: Archive
    
    public init?(fileURL: URL)
    {
        self.fileURL = fileURL
        
        guard let archive = Archive(url: fileURL, accessMode: .read) else { return nil }
        self.archive = archive
        
        guard let infoEntry = archive["info.json"] else { return nil }
        
        do
        {
            let infoData = try archive.extract(infoEntry)
            
            guard let info = try JSONSerialization.jsonObject(with: infoData) as? [String: AnyObject] else { return nil }
            
            guard
                let name = info["name"] as? String,
                let identifier = info["identifier"] as? String,
                let isDebugModeEnabled = info["debug"] as? Bool,
                let representationsDictionary = info["representations"] as? RepresentationDictionary
            else { return nil }
            
            #if FRAMEWORK || SWIFT_PACKAGE
            guard let gameType = info["gameTypeIdentifier"] as? GameType else { return nil }
            #else
            guard let gameTypeString = info["gameTypeIdentifier"] as? String else { return nil }
            let gameType = GameType(gameTypeString)
            #endif
            
            self.name = name
            self.identifier = identifier
            self.gameType = gameType
            self.isDebugModeEnabled = isDebugModeEnabled
            
            let representationsSet = ControllerSkin.parsedRepresentations(from: representationsDictionary)
            
            var representations = [Traits: Representation]()
            for representation in representationsSet
            {
                representations[representation.traits] = representation
            }
            self.representations = representations
            
            guard self.representations.count > 0 else { return nil }
        }
        catch let error as NSError
        {
            print("\(error) \(error.userInfo)")
            
            return nil
        }
    }
    
    // Sometimes, recursion really is the best solution ¯\_(ツ)_/¯
    private static func parsedRepresentations(from representationsDictionary: RepresentationDictionary, device: Device? = nil, displayType: DisplayType? = nil, orientation: Orientation? = nil) -> Set<Representation>
    {
        var representations = Set<Representation>()
        
        for (key, dictionary) in representationsDictionary
        {
            if device == nil
            {
                guard let device = Device(rawValue: key), let dictionary = dictionary as? RepresentationDictionary else { continue }
                
                representations.formUnion(self.parsedRepresentations(from: dictionary, device: device))
            }
            else if displayType == nil
            {
                if let displayType = DisplayType(rawValue: key), let dictionary = dictionary as? RepresentationDictionary
                {
                    representations.formUnion(self.parsedRepresentations(from: dictionary, device: device, displayType: displayType))
                }
                else
                {
                    // Key doesn't exist, so we continue with the same dictionary we're currently iterating, but pass in .standard for displayMode
                    representations.formUnion(self.parsedRepresentations(from: representationsDictionary, device: device, displayType: .standard))
                    
                    // Return early to prevent us from repeating the above step multiple times
                    return representations
                }
            }
            else if orientation == nil
            {
                guard
                    let device = device,
                    let displayType = displayType,
                    let orientation = Orientation(rawValue: key)
                else { continue }
                
                let traits = Traits(device: device, displayType: displayType, orientation: orientation)
                if let representation = Representation(traits: traits, dictionary: dictionary)
                {
                    representations.insert(representation)
                }
            }
        }
        
        return representations
    }
}

public extension ControllerSkin
{
    static func standardControllerSkin(for gameType: GameType) -> ControllerSkin?
    {
        guard
            let deltaCore = Delta.core(for: gameType),
            let fileURL = deltaCore.resourceBundle.url(forResource: "Standard", withExtension: "deltaskin")
        else { return nil }
        
        let controllerSkin = ControllerSkin(fileURL: fileURL)
        return controllerSkin
    }
}

public extension ControllerSkin
{
    func supports(_ traits: Traits) -> Bool
    {
        let representation = self.representations[traits]
        return representation != nil
    }
    
    func thumbstick(for item: ControllerSkin.Item, traits: Traits, preferredSize: Size) -> (UIImage, CGSize)?
    {
        guard let representation = self.representation(for: traits) else { return nil }
        guard let imageName = item.thumbstickImageName, let size = item.thumbstickSize else { return nil }
        guard let entry = self.archive[imageName] else { return nil }
        
        let cacheKey = imageName + self.cacheKey(for: traits, size: preferredSize)
        
        if let image = self.imageCache.object(forKey: cacheKey as NSString)
        {
            return (image, size)
        }
        
        let thumbstickImage: UIImage?
        
        do
        {
            let data = try self.archive.extract(entry)
            
            switch (imageName as NSString).pathExtension.lowercased()
            {
            case "pdf":
                let assetSize = AssetSize(size: preferredSize)
                guard let targetSize = assetSize.targetSize(for: representation.traits) else { return nil }
                
                let thumbstickSize = CGSize(width: size.width * targetSize.width, height: size.height * targetSize.height)
                thumbstickImage = UIImage.image(withPDFData: data, targetSize: thumbstickSize)
                
            default:
                thumbstickImage = UIImage(data: data, scale: 1.0)
            }
        }
        catch
        {
            print(error)
            
            return nil
        }
        
        guard let image = thumbstickImage else { return nil }
        
        self.imageCache.setObject(image, forKey: cacheKey as NSString)
        
        return (image, size)
    }
    
    func image(for traits: Traits, preferredSize: Size) -> UIImage?
    {
        guard let representation = self.representation(for: traits) else { return nil }
        
        let cacheKey = self.cacheKey(for: traits, size: preferredSize)
        
        if let image = self.imageCache.object(forKey: cacheKey as NSString)
        {
            return image
        }
        
        var returnedImage: UIImage? = nil
        
        switch preferredSize
        {
        case .small:
            if let image = self.image(for: representation, assetSize: AssetSize(size: .small)) { returnedImage = image }
            else if let image = self.image(for: representation, assetSize: AssetSize(size: .small, resizable: true)) { returnedImage = image }
            else if let image = self.image(for: representation, assetSize: AssetSize(size: .medium)) { returnedImage = image }
            else if let image = self.image(for: representation, assetSize: AssetSize(size: .large)) { returnedImage = image }
            
        case .medium:
            // First, attempt to load a medium image
            if let image = self.image(for: representation, assetSize: AssetSize(size: .medium)) { returnedImage = image }
                
                // If a medium image doesn't exist, fallback to trying to load a medium resizable image
            else if let image = self.image(for: representation, assetSize: AssetSize(size: .medium, resizable: true)) { returnedImage = image }
                
                // If neither medium nor resizable exists, check for a large image (because downscaling large is better than upscaling small)
            else if let image = self.image(for: representation, assetSize: AssetSize(size: .large)) { returnedImage = image }
                
                // If still no images exist, finally check the small image size
            else if let image = self.image(for: representation, assetSize: AssetSize(size: .small)) { returnedImage = image }
            
        case .large:
            if let image = self.image(for: representation, assetSize: AssetSize(size: .large)) { returnedImage = image }
            else if let image = self.image(for: representation, assetSize: AssetSize(size: .large, resizable: true)) { returnedImage = image }
            else if let image = self.image(for: representation, assetSize: AssetSize(size: .medium)) { returnedImage = image }
            else if let image = self.image(for: representation, assetSize: AssetSize(size: .small)) { returnedImage = image }
            
        }
        
        if let image = returnedImage
        {
            self.imageCache.setObject(image, forKey: cacheKey as NSString)
        }
        
        return returnedImage
    }
    
    func inputs(for traits: Traits, at point: CGPoint) -> [Input]?
    {
        guard let representation = self.representation(for: traits) else { return nil }
        
        var inputs: [Input] = []
        
        for item in representation.items
        {
            guard item.extendedFrame.contains(point) else { continue }
            
            switch item.inputs
            {
            // Don't return inputs for thumbsticks or touch screens since they're handled separately.
            case .directional where item.kind == .thumbstick: break
            case .touch: break
                
            case .standard(let itemInputs):
                inputs.append(contentsOf: itemInputs)
            
            case let .directional(up, down, left, right):

                let divisor: CGFloat
                if case .thumbstick = item.kind
                {
                    divisor = 2.0
                }
                else
                {
                    divisor = 3.0
                }
                
                let topRect = CGRect(x: item.extendedFrame.minX, y: item.extendedFrame.minY, width: item.extendedFrame.width, height: (item.frame.height / divisor) + (item.frame.minY - item.extendedFrame.minY))
                let bottomRect = CGRect(x: item.extendedFrame.minX, y: item.frame.maxY - item.frame.height / divisor, width: item.extendedFrame.width, height: (item.frame.height / divisor) + (item.extendedFrame.maxY - item.frame.maxY))
                let leftRect = CGRect(x: item.extendedFrame.minX, y: item.extendedFrame.minY, width: (item.frame.width / divisor) + (item.frame.minX - item.extendedFrame.minX), height: item.extendedFrame.height)
                let rightRect = CGRect(x: item.frame.maxX - item.frame.width / divisor, y: item.extendedFrame.minY, width: (item.frame.width / divisor) + (item.extendedFrame.maxX - item.frame.maxX), height: item.extendedFrame.height)
                
                if topRect.contains(point)
                {
                    inputs.append(up)
                }
                
                if bottomRect.contains(point)
                {
                    inputs.append(down)
                }
                
                if leftRect.contains(point)
                {
                    inputs.append(left)
                }
                
                if rightRect.contains(point)
                {
                    inputs.append(right)
                }
            }
        }
        
        return inputs
    }
    
    func items(for traits: Traits) -> [Item]?
    {
        guard let representation = self.representation(for: traits) else { return nil }
        return representation.items
    }
    
    func isTranslucent(for traits: Traits) -> Bool?
    {
        guard let representation = self.representation(for: traits) else { return nil }
        return representation.isTranslucent
    }
    
    func gameScreenFrame(for traits: Traits) -> CGRect?
    {
        guard let representation = self.representation(for: traits) else { return nil }
        return representation.screens?.first?.outputFrame
    }
    
    func screens(for traits: Traits) -> [ControllerSkin.Screen]?
    {
        guard let representation = self.representation(for: traits) else { return nil }
        return representation.screens
    }
    
    func aspectRatio(for traits: ControllerSkin.Traits) -> CGSize?
    {
        guard let representation = self.representation(for: traits) else { return nil }
        return representation.aspectRatio
    }
}

private extension ControllerSkin
{
    func image(for representation: Representation, assetSize: AssetSize) -> UIImage?
    {
        guard let filename = representation.assets[assetSize], let entry = self.archive[filename] else { return nil }
        
        do
        {
            let data = try self.archive.extract(entry)
            
            let image: UIImage?
            
            switch assetSize
            {
            case .small, .medium, .large:
                guard let imageScale = assetSize.imageScale(for: representation.traits) else { return nil }
                image = UIImage(data: data, scale: imageScale)
                
            case .resizable:
                guard let targetSize = assetSize.targetSize(for: representation.traits) else { return nil }
                image = UIImage.image(withPDFData: data, targetSize: targetSize)
            }
            
            return image
        }
        catch
        {
            print(error)
            
            return nil
        }
    }
    
    func cacheKey(for traits: Traits, size: Size) -> String
    {
        return String(describing: traits) + "-" + String(describing: size)
    }
    
    func representation(for traits: Traits) -> Representation?
    {
        let representation = self.representations[traits]
        guard representation == nil else {
            return representation
        }
        
        guard let fallbackTraits = self.supportedTraits(for: traits) else {
            return nil
        }
        
        let fallbackRepresentation = self.representations[fallbackTraits]
        return fallbackRepresentation
    }
}

extension ControllerSkin
{
    public struct Item
    {
        public enum Kind: Equatable
        {
            case button
            case dPad
            case thumbstick
            case touchScreen
        }
        
        public enum Inputs
        {
            case standard([Input])
            case directional(up: Input, down: Input, left: Input, right: Input)
            case touch(x: Input, y: Input)
            
            public var allInputs: [Input] {
                switch self
                {
                case .standard(let inputs): return inputs
                case let .directional(up, down, left, right): return [up, down, left, right]
                case let .touch(x, y): return [x, y]
                }
            }
        }
        
        public var kind: Kind
        public var inputs: Inputs
        
        public var frame: CGRect
        public var extendedFrame: CGRect
        
        fileprivate var thumbstickImageName: String?
        fileprivate var thumbstickSize: CGSize?
        
        fileprivate init?(dictionary: [String: AnyObject], extendedEdges: ExtendedEdges, mappingSize: CGSize)
        {
            guard
                let frameDictionary = dictionary["frame"] as? [String: CGFloat], let frame = CGRect(dictionary: frameDictionary)
                else { return nil }
            
            if let inputs = dictionary["inputs"] as? [String]
            {
                self.kind = .button
                self.inputs = .standard(inputs.map { AnyInput(stringValue: $0, intValue: nil, type: .controller(.controllerSkin)) })
            }
            else if let inputs = dictionary["inputs"] as? [String: String]
            {
                if let up = inputs["up"], let down = inputs["down"], let left = inputs["left"], let right = inputs["right"]
                {
                    let isContinuous: Bool
                    
                    if
                        let thumbstickDictionary = dictionary["thumbstick"] as? [String: Any],
                        let imageName = thumbstickDictionary["name"] as? String,
                        let width = thumbstickDictionary["width"] as? CGFloat,
                        let height = thumbstickDictionary["height"] as? CGFloat
                    {
                        self.thumbstickImageName = imageName
                        self.thumbstickSize = CGSize(width: CGFloat(width) / mappingSize.width, height: CGFloat(height) / mappingSize.height)
                        
                        self.kind = .thumbstick
                        isContinuous = true
                    }
                    else
                    {
                        self.kind = .dPad
                        isContinuous = false
                    }
                    
                    self.inputs = .directional(up: AnyInput(stringValue: up, intValue: nil, type: .controller(.controllerSkin), isContinuous: isContinuous),
                                               down: AnyInput(stringValue: down, intValue: nil, type: .controller(.controllerSkin), isContinuous: isContinuous),
                                               left: AnyInput(stringValue: left, intValue: nil, type: .controller(.controllerSkin), isContinuous: isContinuous),
                                               right: AnyInput(stringValue: right, intValue: nil, type: .controller(.controllerSkin), isContinuous: isContinuous))
                }
                else if let x = inputs["x"], let y = inputs["y"]
                {
                    self.kind = .touchScreen
                    self.inputs = .touch(x: AnyInput(stringValue: x, intValue: nil, type: .controller(.controllerSkin), isContinuous: true),
                                         y: AnyInput(stringValue: y, intValue: nil, type: .controller(.controllerSkin), isContinuous: true))
                }
                else
                {
                    return nil
                }
            }
            else
            {
                return nil
            }
            
            let overrideExtendedEdges = ExtendedEdges(dictionary: dictionary["extendedEdges"] as? [String: CGFloat])
            
            var extendedEdges = extendedEdges
            extendedEdges.top = overrideExtendedEdges.top ?? extendedEdges.top
            extendedEdges.bottom = overrideExtendedEdges.bottom ?? extendedEdges.bottom
            extendedEdges.left = overrideExtendedEdges.left ?? extendedEdges.left
            extendedEdges.right = overrideExtendedEdges.right ?? extendedEdges.right
            
            var extendedFrame = frame
            extendedFrame.origin.x -= extendedEdges.left ?? 0
            extendedFrame.origin.y -= extendedEdges.top ?? 0
            extendedFrame.size.width += (extendedEdges.left ?? 0) + (extendedEdges.right ?? 0)
            extendedFrame.size.height += (extendedEdges.top ?? 0) + (extendedEdges.bottom ?? 0)
            
            // Convert frames to relative values.
            let scaleTransform = CGAffineTransform(scaleX: 1.0 / mappingSize.width, y: 1.0 / mappingSize.height)
            self.frame = frame.applying(scaleTransform)
            self.extendedFrame = extendedFrame.applying(scaleTransform)
        }
    }
}

extension ControllerSkin.Item: Hashable
{
    public static func ==(lhs: ControllerSkin.Item, rhs: ControllerSkin.Item) -> Bool
    {
        guard
            lhs.kind == rhs.kind,
            lhs.thumbstickImageName == rhs.thumbstickImageName, lhs.thumbstickSize == rhs.thumbstickSize,
            lhs.inputs.allInputs.map({ $0.stringValue }) == rhs.inputs.allInputs.map({ $0.stringValue }),
            lhs.frame == rhs.frame && lhs.extendedFrame == rhs.extendedFrame
        else { return false }
        
        return true
    }
    
    public func hash(into hasher: inout Hasher)
    {
        switch self.kind
        {
        case .button: hasher.combine(0)
        case .dPad: hasher.combine(1)
        case .thumbstick: hasher.combine(2)
        case .touchScreen: hasher.combine(3)
        }
        
        hasher.combine(self.thumbstickImageName)
        hasher.combine(self.thumbstickSize?.width)
        hasher.combine(self.thumbstickSize?.height)
        
        for input in self.inputs.allInputs
        {
            hasher.combine(input.stringValue)
        }
        
        for frame in [self.frame, self.extendedFrame]
        {
            hasher.combine(frame.origin.x)
            hasher.combine(frame.origin.y)
            hasher.combine(frame.width)
            hasher.combine(frame.height)
        }
    }
}

private extension ControllerSkin
{
    struct ExtendedEdges
    {
        var top: CGFloat?
        var bottom: CGFloat?
        var left: CGFloat?
        var right: CGFloat?
        
        init(dictionary: [String: CGFloat]?)
        {
            self.top = dictionary?["top"]
            self.bottom = dictionary?["bottom"]
            self.left = dictionary?["left"]
            self.right = dictionary?["right"]
        }
    }
    
    enum AssetSize: RawRepresentable, Hashable
    {
        case small
        case medium
        case large
        indirect case resizable(assetSize: AssetSize?)
        
        // If we're resizable, return our associated AssetSize
        // Otherwise, we just return self
        var unwrapped: AssetSize?
        {
            if case .resizable(let size) = self
            {
                if let size = size
                {
                    return size
                }
                else
                {
                    return nil
                }
            }
            else
            {
                return self
            }
        }
        
        /// Hashable
        var hashValue: Int {
            return self.rawValue.hashValue
        }
        
        /// RawRepresentable
        typealias RawValue = String
        
        var rawValue: String {
            switch self
            {
            case .small:     return "small"
            case .medium:    return "medium"
            case .large:     return "large"
            case .resizable: return "resizable"
            }
        }
        
        init?(rawValue: String)
        {
            switch rawValue
            {
            case "small":     self = .small
            case "medium":    self = .medium
            case "large":     self = .large
            case "resizable": self = .resizable(assetSize: nil)
            default:          return nil
            }
        }
        
        init(size: Size, resizable: Bool = false)
        {
            switch size
            {
            case .small:  self = .small
            case .medium: self = .medium
            case .large:  self = .large
            }
            
            if resizable
            {
                self = .resizable(assetSize: self)
            }
        }
        
        // Should always be used over the associated value for .resizable because it handles orientation
        func targetSize(for traits: ControllerSkin.Traits) -> CGSize?
        {
            guard let assetSize = self.unwrapped else { return nil }
            
            var targetSize: CGSize
            
            switch (traits.device, traits.displayType, assetSize)
            {
            case (.iphone, .standard, .small): targetSize = CGSize(width: 320, height: 568)
            case (.iphone, .standard, .medium): targetSize = CGSize(width: 375, height: 667)
            case (.iphone, .standard, .large): targetSize = CGSize(width: 414, height: 736)
                
            case (.iphone, .edgeToEdge, _): targetSize = CGSize(width: 375, height: 812)
            case (.iphone, .splitView, _): return nil
                
            case (.ipad, _,  .small): targetSize = CGSize(width: 768, height: 1024)
            case (.ipad, _, .medium): targetSize = CGSize(width: 834, height: 1112)
            case (.ipad, _, .large): targetSize = CGSize(width: 1024, height: 1366)
                
            case (_, _, .resizable): return nil
            }
            
            switch traits.orientation
            {
            case .portrait: break
            case .landscape: targetSize = CGSize(width: targetSize.height, height: targetSize.width)
            }
            
            return targetSize
        }
        
        func imageScale(for traits: ControllerSkin.Traits) -> CGFloat?
        {
            guard let assetSize = self.unwrapped else { return nil }
            
            switch (traits.device, traits.displayType, assetSize)
            {
            case (.iphone, .standard, .small): return 2.0
            case (.iphone, .standard, .medium): return 2.0
            case (.iphone, .standard, .large): return 3.0
                
            case (.iphone, .edgeToEdge, _): return 3.0
            case (.iphone, .splitView, _): return nil
                
            case (.ipad, .standard, _): return 2.0
            case (.ipad, .edgeToEdge, _): return nil
            case (.ipad, .splitView, _): return 2.0
                
            case (_, _, .resizable): return nil
            }
        }
    }
    
    struct Representation: Hashable, CustomStringConvertible
    {
        let traits: Traits
        
        let assets: [AssetSize: String]
        let isTranslucent: Bool
        let screens: [Screen]?
        let aspectRatio: CGSize
        
        let items: [Item]
        
        /// CustomStringConvertible
        var description: String {
            return self.traits.description
        }
        
        init?(traits: Traits, dictionary: [String: AnyObject])
        {
            guard
                let mappingSizeDictionary = dictionary["mappingSize"] as? [String: CGFloat], let mappingSize = CGSize(dictionary: mappingSizeDictionary),
                let itemsArray = dictionary["items"] as? [[String: AnyObject]],
                let assetsDictionary = dictionary["assets"] as? [String: String]
            else { return nil }
            
            self.aspectRatio = mappingSize
            
            self.traits = traits
            
            let extendedEdges = ExtendedEdges(dictionary: dictionary["extendedEdges"] as? [String: CGFloat])
            
            var items = [Item]()
            for dictionary in itemsArray
            {
                if let item = Item(dictionary: dictionary, extendedEdges: extendedEdges, mappingSize: mappingSize)
                {
                    items.append(item)
                }
            }
            self.items = items
            
            var assets = [AssetSize: String]()
            for (key, value) in assetsDictionary
            {
                if let size = AssetSize(rawValue: key)
                {
                    assets[size] = value
                }
            }
            self.assets = assets
            
            guard self.assets.count > 0 else { return nil }
            
            self.isTranslucent = dictionary["translucent"] as? Bool ?? false
            
            if
                let gameScreenFrameDictionary = dictionary["gameScreenFrame"] as? [String: CGFloat],
                let gameScreenFrame = CGRect(dictionary: gameScreenFrameDictionary)
            {
                let scaleTransform = CGAffineTransform(scaleX: 1.0 / mappingSize.width, y: 1.0 / mappingSize.height)
                let frame = gameScreenFrame.applying(scaleTransform)
                
                self.screens = [Screen(inputFrame: nil, outputFrame: frame)]
            }
            else if let screensArray = dictionary["screens"] as? [[String: Any]]
            {
                let scaleTransform = CGAffineTransform(scaleX: 1.0 / mappingSize.width, y: 1.0 / mappingSize.height)
                
                let screens = screensArray.compactMap { (screenDictionary) -> Screen? in
                    guard
                        let outputFrameDictionary = screenDictionary["outputFrame"] as? [String: CGFloat],
                        let outputFrame = CGRect(dictionary: outputFrameDictionary)
                    else { return nil }
                    
                    let normalizedOutputFrame = outputFrame.applying(scaleTransform)
                    
                    var inputFrame: CGRect?
                    if let dictionary = screenDictionary["inputFrame"] as? [String: CGFloat], let frame = CGRect(dictionary: dictionary)
                    {
                        inputFrame = frame
                    }
                    
                    var filters: [CIFilter]?
                    if let filtersArray = screenDictionary["filters"] as? [[String: Any]]
                    {
                        filters = filtersArray.compactMap { (dictionary) -> CIFilter? in
                            guard let name = dictionary["name"] as? String else { return nil }
                            let parameters = dictionary["parameters"] as? [String: Any]
                            
                            guard let filter = CIFilter(name: name) else { return nil }
                            
                            var filterParameters = [String: Any]()
                            
                            for (parameter, value) in parameters ?? [:]
                            {
                                guard let attribute = filter.attributes[parameter] as? [String: Any] else { continue }
                                guard let className = attribute[kCIAttributeClass] as? String else { continue }
                                guard let attributeType = attribute[kCIAttributeType] as? String else { continue }
                                
                                let mappedValue: Any
                                
                                switch (className, value)
                                {
                                case (NSStringFromClass(NSNumber.self), let value as NSNumber):
                                    mappedValue = value
                                    
                                case (NSStringFromClass(CIVector.self), let value as [String: CGFloat]):
                                    guard let x = value["x"], let y = value["y"] else { continue }
                                    
                                    if let width = value["width"], let height = value["height"]
                                    {
                                        let vector = CIVector(cgRect: CGRect(x: x, y: y, width: width, height: height))
                                        mappedValue = vector
                                    }
                                    else
                                    {
                                        let vector = CIVector(x: x, y: y)
                                        mappedValue = vector
                                    }
                                    
                                case (NSStringFromClass(CIColor.self), let value as [String: CGFloat]):
                                    guard let red = value["r"], let green = value["g"], let blue = value["b"] else { continue }
                                    
                                    let alpha = value["a"] ?? 255.0
                                    
                                    let color = CIColor(red: red / 255.0, green: green / 255.0, blue: blue / 255.0, alpha: alpha / 255.0)
                                    mappedValue = color
                                    
                                case (NSStringFromClass(NSValue.self), let value as [String: CGFloat]) where attributeType == kCIAttributeTypeTransform:
                                    let transform: CGAffineTransform
                                    
                                    if let angle = value["rotation"]
                                    {
                                        let radians = angle * .pi / 180
                                        transform = CGAffineTransform.identity.rotated(by: radians)
                                    }
                                    else
                                    {
                                        let x = value["scaleX"] ?? 1
                                        let y = value["scaleY"] ?? 1
                                        
                                        transform = CGAffineTransform(scaleX: x, y: y)
                                    }
                                    
                                    let value = NSValue(cgAffineTransform: transform)
                                    mappedValue = value
                                                                        
                                default: continue
                                }
                                
                                filter.setValue(mappedValue, forKey: parameter)
                            }
                            
                            return filter
                        }
                    }
                    
                    let screen = Screen(inputFrame: inputFrame, outputFrame: normalizedOutputFrame, filters: filters)
                    return screen
                }
                
                self.screens = screens
            }
            else
            {
                self.screens = nil
            }
        }
        
        /// Equatable
        static func ==(lhs: ControllerSkin.Representation, rhs: ControllerSkin.Representation) -> Bool
        {
            return lhs.traits == rhs.traits
        }
        
        /// Hashable
        func hash(into hasher: inout Hasher)
        {
            hasher.combine(self.traits)
        }
    }
}
