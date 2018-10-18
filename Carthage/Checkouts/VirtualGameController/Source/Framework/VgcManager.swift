//
//  VgcManager.swift
//  
//
//  Created by Rob Reuss on 10/8/15.
//
//

import Foundation
#if !(os(watchOS))
import GameController
#endif
#if os(iOS) || os(tvOS) // Need this only for UIDevice
    import UIKit
#endif
#if os(watchOS)
    import WatchKit
#endif

/// The "elements" global should be considered private from the Central development side of things.
/// In that context, it provides the backing state of the software controller for
/// the various profiles, and should not be accessed directly.  
/// 
/// On the peripheral development side, it is a key part of developing a custom software-based
/// peripheral, providing the basis for sending element values to the Central.
///
/// This variable provides a reference to an Elements object that acts as an
/// an interface to both standard and custom elements, provides a couple of methods
/// for access those sets, and provides access to individual Element instances for
/// each supported element.  
///

public var customElements: CustomElementsSuperclass!

///
/// appRole:
/// The appRole value must ONLY be set by passing it as a parameter to startAs.
///
/// - parameter .Central:           The consumer of the Peripheral data, typically a game.
///
/// - parameter .Peripheral:        A game controller that may be a hardware controller or a
///                                 VGC software controller, it receives input from a user through
///                                 Elements (buttons, thumbsticks, accelerometer, etc.) and sends
///                                 those values to either a Bridge or a Central.
///
/// - parameter .Bridge:            An intermediary between Peripherals and the Central, which
///                                 effectively functions as both a Central and Peripheral, usually
///                                 forwarding element values to the Central, although it may also
///                                 process those values in terms of calling handlers. An iPhone
///                                 positioned in a slide-on controller will typically function as
///                                 as a Bridge (although it can also be a Central).  An iPhone paired
///                                 with an Apple Watch that is functioning as a Peripheral will act
///                                 as a Bridge.  
///
/// - parameter .EnhancementBridge:  Special Bridge mode for using a form-fitting/slide-on controller
///                                 with an iPhone.  Prevents additional Peripherals from connecting.
///
@objc public enum AppRole: Int, CustomStringConvertible {
    
    case Undefined = 0
    case Central = 1
    case Peripheral = 2
    case Bridge = 3
    case EnhancementBridge = 4
    case MultiplayerPeer = 5
    
    public var description : String {
        switch self {
        case .Undefined: return "Undefined"
        case .Central: return "Central"
        case .Peripheral: return "Peripheral"
        case .Bridge: return "Bridge"
        case .EnhancementBridge: return "Enhancement Bridge"
        case .MultiplayerPeer: return "Multiplayer Peer"
        }
    }
}

///
/// ControllerType enumeration: Most values are for informational purposes,
/// except MFiHardware, which is used to trigger the "wrapped" approach to
/// handling hardware controllers in VgcController.
///

@objc public enum ControllerType: Int, CustomStringConvertible {
    case Software
    case MFiHardware
    case ICadeHardware
    case BridgedMFiHardware
    case BridgedICadeHardware
    case Watch
    
    public var description : String {
        switch self {
        case .MFiHardware: return "MFi Hardware"
        case .ICadeHardware: return "iCade Hardware"
        case .Software: return "Software"
        case .BridgedMFiHardware: return "Bridged MFi Hardware"
        case .BridgedICadeHardware: return "Bridged iCade Hardware"
        case .Watch: return "Watch"
        }
    }
}

@objc public enum ProfileType: Int, CustomStringConvertible {
    
    case Unknown
    case GenericGamepad
    case MicroGamepad
    case Gamepad
    case ExtendedGamepad
    case Motion
    case Watch
    
    public var description : String {
        switch self {
        case .Unknown: return "Unknown"
        case .GenericGamepad: return "GenericGamepad"
        case .MicroGamepad: return "MicroGamepad"
        case .Gamepad: return "Gamepad"
        case .ExtendedGamepad: return "ExtendedGamepad"
        case .Motion: return "Motion"
        case .Watch: return "Watch"
        }
    }
    
    var pathComponentRead : String {
        switch self {
        case .Unknown: return ""
        case .GenericGamepad: return ""
        case .MicroGamepad: return "microGamepad"
        case .Gamepad: return "gamepad"
        case .ExtendedGamepad: return "extendedGamepad"
        case .Motion: return "motion"
        case .Watch: return "extendedGamepad"
        }
    }
    
    var pathComponentWrite : String {
        switch self {
        case .Unknown: return ""
        case .GenericGamepad: return ""
        case .MicroGamepad: return "vgcMicroGamepad"
        case .Gamepad: return "vgcGamepad"
        case .ExtendedGamepad: return "vgcExtendedGamepad"
        case .Motion: return "vgcMotion"
        case .Watch: return "vgcExtendedGamepad"
        }
    }
    
}

/// For transmitted element value messages...
let messageValueSeperator = ":"

#if !os(watchOS)
@objc open class VgcService: NSObject {
    
    open var name: String
    open var type: AppRole
    internal var netService: NetService
    
    @objc open var fullName: String { return "\(name) (\(type.description))" }
    
    init(name: String, type: AppRole, netService: NetService) {
        self.name = name
        self.type = type
        self.netService = netService
    }
}
#endif

@objc open class VgcManager: NSObject {
   
    // Define this as a singleton although never used as such; only class methods used
    @objc static let sharedInstance = VgcManager()
    fileprivate override init() {}

    // Default to being a Peripheral
    @objc open static var appRole: AppRole = .Peripheral
    
    #if !os(watchOS)
    /// Used by the Central to configure a software controller, in terms of profile type, background
    /// color and such
    open static var peripheralSetup = VgcPeripheralSetup()
    #endif
    
    ///
    /// Shared set of elements (in contrast to controllers on a Central/Bridge, each
    /// of which have their own set of elements).
    ///
    @objc open static var elements = Elements()
    
    /// Log Level "Debug" is a standard level of logging for debugging - set to "Error" for release
    @objc open static var loggerLogLevel: LogLevel = LogLevel.Debug {
        didSet {
            vgcLogDebug("Set logLevel: \(VgcManager.loggerLogLevel)")
        }
    }
    
    /// Use either NSLog or Swift "print" for logging - NSLog gives more detail
    @objc open static var loggerUseNSLog: Bool = false {
        didSet {
            vgcLogDebug("Set NSLog logging to: \(VgcManager.loggerUseNSLog)")
        }
    }
    
    ///
    /// Used as a component of the bonjour names for the various app types.
    /// This should be set to something that uniquely identifies your app.
    ///
    @objc open static var appIdentifier = "pelau"

    @objc static var serviceDomain = "local"
    
    @objc open static var uniqueServiceIdentifierString: String {
        get {

            if VgcManager.useRandomServiceName == true {
                var usi: String
                let defaults = UserDefaults.standard
                if let usi = defaults.string(forKey: "includeUniqueServiceIdentifier") {
                    vgcLogDebug("Found Unique Service Identifier")
                    return usi
                } else {
                    usi = UUID().uuidString
                    vgcLogDebug("Created new Unique Service Identifier")
                    defaults.set(usi, forKey: "includeUniqueServiceIdentifier")
                    return usi
                }
            } else {
                #if os(iOS) || os(tvOS)
                    return UIDevice.current.name
                #endif
                
                #if os(OSX)
                    return Host.current().localizedName!
                #endif
            }
//            return ""
        }
    }

    @objc static var bonjourTypeCentral: String { return "_\(VgcManager.appIdentifier)_central._tcp." }
    @objc static var bonjourTypeBridge: String { return "_\(VgcManager.appIdentifier)_bridge._tcp." }
    
    ///
    /// An app in Bridge mode can call it's handlers or simply relay
    /// data forward to the Central.  Relaying is more performant.
    ///
    @objc open static var bridgeRelayOnly = false

    #if !os(watchOS)
    ///
    /// The vendor of the iCade controller in use, or .Disabled if the functionality
    /// is not being used.  The Mode can be set at any time, and would presumably be
    /// in response to an end-user selecting the type of iCade controller they've paired
    /// with their iOS device.
    ///
    open static var iCadeControllerMode: IcadeControllerMode = .Disabled {

        didSet {
            
            #if !os(watchOS)
            if iCadeControllerMode != .Disabled { iCadePeripheral = VgcIcadePeripheral() } else { iCadePeripheral = nil }
            #endif
            
        }
    }

    open static var iCadePeripheral: VgcIcadePeripheral!
    #endif
    
    ///
    /// We support mapping from either the Peripheral or Central side.  Central-side mapping
    /// is recommended; it is more efficient because two values do not need to be transmitted.
    /// Central-side mapping also works with hardware controllers.
    ///
    @objc open static var usePeripheralSideMapping: Bool = false
    
    ///
    /// Filter duplicate float values, with comparison occuring at a certain
    /// degree of decimal precision
    ///
    @objc open static var enableDupFiltering = false
    @objc open static var dupFilteringPrecision = 2

    @objc open static var netServiceBufferSize = 4080
    @objc open static var maxDataBufferSizeMessages = 512 // Number of messages to hold in a FIFO buffer until stream returns
    
    @objc open static var netServiceLatencyLogging = false // DO NOT USE: Unreliable method.  Use "Test_Performance_Peripheral" and "Test_Performance_Central" projects instead
    
    // The header length of messages
    @objc static var netServiceHeaderLength: Int {
        
        get {
            if VgcManager.netServiceLatencyLogging {
                return 17
            } else {
                return 9
            }
        }
        
    }
    
    // Indicator of start of header
    @objc static var headerIdentifier: UInt32 = 2584594329 // Random UInt32
    
    // Maximum time to wait for both the small and large data streams to be opened, in seconds
    @objc static var maxTimeForMatchingStreams = 5.0
    
    // Disabling peer-to-peer (provides Bluetooth fallback) may improve performance if needed
    // NOTE: This property cannot be set after startAs is called.  Instead, use the version of
    // startAs that includes the includesPeerToPeer parameter.
    @objc static var includesPeerToPeer = false
    
    // Local Game Controller functionalty allows the use of the MFI/VGC interface for local functionality.
    // Handlers can be created when the localControllerDidConnect notification is received, and game-play
    // functionality placed in those handlers.  This functionality is useful if you want to have local peripheral
    // activity to both the local game and a remote game, for example if implementing an ARKit environment
    // where controller activity is needed by both instance of the app (on both devices).
    @objc open static var enableLocalController = false
    
    // Include unique string in bonjour name to allow multiple unique central/peripheral combos to connect
    // to one another (bi-directional).  It effectively gives each of the two Central's it's own unique service
    // identity.  Uses a UID in the bonjour name.
    @objc open static var useRandomServiceName = false
    
    ///
    /// Logs measurements of mesages transmitted/received and displays in console
    ///
    @objc open static var performanceSamplingEnabled: Bool { get { return performanceSamplingDisplayFrequency > 0 } }
    
    ///
    /// Controls how long we wait before averaging the number of messages
    /// transmitted/received per second when logging performance.  Set to 0 to disable.
    ///
    @objc open static var performanceSamplingDisplayFrequency: Float = 0.0

    #if !os(watchOS)
    @objc open static var peripheral: Peripheral!
    
    open var controller: VgcController {
        get {
            return VgcManager.peripheral.controller
        }
    }
    
    #endif
    
    /// Network name for publishing service, defaults to device name
    open static var centralServiceName = VgcManager.uniqueServiceIdentifierString

    #if !os(watchOS)
    open class func publishCentralService() {
        if appRole == .Central {
            VgcController.centralPublisher.publishService()
        } else {
            vgcLogError("Refused to publish Central service because appRole is not Central")
        }
    }
    
    open class func unpublishCentralService() {
        if appRole == .Central || appRole == .MultiplayerPeer {
            VgcController.centralPublisher.unpublishService()
        } else {
            vgcLogError("Refused to unpublish Central service because appRole is not Central")
        }
    }
    #endif
    
    /// Simplified version of startAs when custom mapping and custom elements are not needed
    @objc open class func startAs(_ appRole: AppRole, appIdentifier: String) {
        VgcManager.startAs(appRole, appIdentifier: appIdentifier, customElements: CustomElementsSuperclass(), customMappings: CustomMappingsSuperclass())
    }
    
    /// Simplified version of startAs when custom mapping and custom elements are not needed, but includesPeerToPeer is
    @objc open class func startAs(_ appRole: AppRole, appIdentifier: String, includesPeerToPeer: Bool) {
        VgcManager.startAs(appRole, appIdentifier: appIdentifier, customElements: CustomElementsSuperclass(), customMappings: CustomMappingsSuperclass(), includesPeerToPeer: includesPeerToPeer)
    }
    
    /// Must use this startAs method to turn on peer to peer functionality (Bluetooth)
    @objc open class func startAs(_ appRole: AppRole, appIdentifier: String, customElements: CustomElementsSuperclass!, customMappings: CustomMappingsSuperclass!, includesPeerToPeer: Bool) {
        VgcManager.includesPeerToPeer = includesPeerToPeer
        startAs(appRole, appIdentifier: appIdentifier, customElements: customElements, customMappings: customMappings)
    }
    
    /// Must use this startAs method to turn on peer to peer functionality (Bluetooth) and local game controller functionality
    @objc open class func startAs(_ appRole: AppRole, appIdentifier: String, customElements: CustomElementsSuperclass!, customMappings: CustomMappingsSuperclass!, includesPeerToPeer: Bool, enableLocalController: Bool) {
        VgcManager.includesPeerToPeer = includesPeerToPeer
        if appRole == .Peripheral || appRole == .MultiplayerPeer {
            VgcManager.enableLocalController = enableLocalController
        } else if enableLocalController {
            vgcLogError("Cannot start LOCAL controller as a Central.  Exiting startAs function.")
            return
        }
        if appRole == .MultiplayerPeer {
            vgcLogError("MULTIPEER mode so setting service name to something random (guarenteed unique).")
            useRandomServiceName = true // Must use unique name when operating in peer mode
            vgcLogError("MULTIPEER mode so starting as .Central first.")
            startAs(.Central, appIdentifier: appIdentifier, customElements: customElements, customMappings: customMappings)
            vgcLogError("MULTIPEER mode so starting as .Peripheral second.")
            startAs(.Peripheral, appIdentifier: appIdentifier, customElements: customElements, customMappings: customMappings)
            self.appRole = .MultiplayerPeer
        } else {
            startAs(appRole, appIdentifier: appIdentifier, customElements: customElements, customMappings: customMappings)
        }
    }

    
     ///
    /// Kicks off the search for software controllers.  This is a required method and should be
    /// called early in the application launch process.
    ///
    @objc open class func startAs(_ appRole: AppRole, appIdentifier: String, customElements: CustomElementsSuperclass!, customMappings: CustomMappingsSuperclass!) {

        #if !os(watchOS)
        //if (appRoleVar == .Central) && (VgcManager.peripheral != nil) {
        //    vgcLogError("Cannot call startAs twice for Central and Periperal.  Use .Multiplayer appRole instead.")
        //    return
        //}
        #endif
        
        self.appRole = appRole
        
        if appIdentifier != "" { self.appIdentifier = appIdentifier } else { vgcLogError("You must set appIdentifier to some string") }
        
        var customElements = customElements
        var customMappings = customMappings
        if customElements == nil { customElements = CustomElementsSuperclass()}
        if customMappings == nil { customMappings = CustomMappingsSuperclass()}
        Elements.customElements = customElements
        Elements.customMappings = customMappings
        
        vgcLogDebug("Setting up as a \(VgcManager.appRole.description.uppercased())")
        vgcLogDebug("IncludesPeerToPeer is set to: \(VgcManager.includesPeerToPeer)")

        #if !os(watchOS)

        switch (VgcManager.appRole) {
            
            case .Undefined:
                return
            
            case .Peripheral, .MultiplayerPeer:

                VgcManager.peripheral = Peripheral()
                
                // Default device for software Peripheral, can be overriden by setting the VgcManager.peripheral.deviceInfo property
                VgcManager.peripheral.deviceInfo = DeviceInfo(deviceUID: "", vendorName: "", attachedToDevice: false, profileType: .ExtendedGamepad, controllerType: .Software, supportsMotion: true)
            
                #if os(iOS)
//                    VgcManager.peripheral.watch = VgcWatch(delegate: VgcManager.peripheral)
                #endif
            
            case .Central:
                VgcController.setup()
            
            case .Bridge, .EnhancementBridge:
                
                VgcController.setup()
            }
      
            // Create a controller for use with a peripheral
            if VgcManager.enableLocalController && appRole == .Peripheral {
                vgcLogDebug("Enabling LOCAL game controller")
                self.peripheral.localController = VgcController()
                self.peripheral.localController.isLocalController = true
                self.peripheral.localController.deviceInfo = VgcManager.peripheral.deviceInfo
             }
            
        #endif

    }
    
}

// Convienance function
public func deviceIsTypeOfBridge() -> Bool {
    return VgcManager.appRole == .Bridge || VgcManager.appRole == .EnhancementBridge
}

// Meta information related to the controller.  This object is
// made available for both hardware and software controllers.  It
// supports copying, for use in the bridge/forwarding context, and
// supports archiving for transmission from peripheral to central.

/// DeviceInfo contains key properties of a controller, either hardware or software.  
/// 
/// - parameter deviceUID: Unique identifier for the controller.  Hardware controllers have this built-in.  An arbitrary identifier can be given to a software controller, and the NSUUID().UUIDString function is recommended.
///
/// - parameter vendorName: Built-in to a hardware controller.  For software controllers, either define a name or use an empty string "" and the machine/device name will be used.
///
/// - parameter profileType: Built-in to a hardware controller.  This can be aribtrarily set to either extendedGamepad or Gamepad for a software controller, and will determine what elements are available to the controller.  microGamepad is only available in the tvOS context and is untested with software controllers.
///
/// - parameter supportsMotion: Built-in parameter with a hardware controller (the Apple TV remote is the only hardware controller known to support motion). This can be set when defining a software controller, but would be overriden on the basis of the availabiity of Core Motion.  For example, an OSX-based software controller would report supports motion as false.
///

@objc open class DeviceInfo: NSObject, NSCoding {
    
    @objc internal(set) var deviceUID: String
    @objc internal(set) open var vendorName: String
    @objc internal(set) open var attachedToDevice: Bool
    @objc open var profileType: ProfileType
    @objc internal(set) open var controllerType: ControllerType
    @objc internal(set) open var supportsMotion: Bool
    
    @objc public init(deviceUID: String, vendorName: String, attachedToDevice: Bool, profileType: ProfileType, controllerType: ControllerType, supportsMotion: Bool) {
        var deviceUID = deviceUID
        
        // If no deviceUID is specified, auto-generate a UID and store it to provide
        // a persistent way of identifying the peripheral.
        if deviceUID == "" {
            let defaults = UserDefaults.standard
            if let existingDeviceUID = defaults.string(forKey: "deviceUID") {
                vgcLogDebug("Found existing UID for device: \(existingDeviceUID)")
                deviceUID = existingDeviceUID
            } else {
                deviceUID = UUID().uuidString
                vgcLogDebug("Created new UID for device: \(deviceUID)")
                defaults.set(deviceUID, forKey: "deviceUID")
            }
        }
        
        self.deviceUID = deviceUID
        self.attachedToDevice = attachedToDevice
        self.profileType = profileType
        self.controllerType = controllerType
        self.supportsMotion = supportsMotion
        self.vendorName = vendorName
        
        super.init()
        
        if (self.vendorName == "") {
            #if os(iOS) || os(tvOS)
                self.vendorName = UIDevice.current.name
            #endif
            #if os(OSX)
                self.vendorName = Host.current().localizedName!
            #endif
            #if os(watchOS)
                self.vendorName = WKInterfaceDevice.current().name
            #endif
        }
        if self.vendorName == "" {
            self.vendorName = "Unknown"
        }
        
        if profileType == .MicroGamepad {
            vgcLogError("The use of the .MicroGamepad profile for software-based controllers will lead to unpredictable results.")
        }
        
    }
    
    open override var description: String {
        
        var result: String = "\n"
        result += "Device information:\n\n"
        result += "Vendor:    \(self.vendorName)\n"
        result += "Type:      \(self.controllerType)\n"
        result += "Profile:   \(self.profileType)\n"
        result += "Attached:  \(self.attachedToDevice)\n"
        result += "Motion:    \(self.supportsMotion)\n"
        result += "ID:        \(self.deviceUID)\n"
        return result
        
    }
    
    // The deviceInfo is sent over-the-wire to a Bridge or Central using
    // NSKeyed archiving...
    
    required convenience public init(coder decoder: NSCoder) {
        
        let deviceUID = decoder.decodeObject(forKey: "deviceUID") as! String
        let vendorName = decoder.decodeObject(forKey: "vendorName") as! String
        let attachedToDevice = decoder.decodeBool(forKey: "attachedToDevice")
        let profileType = ProfileType(rawValue: decoder.decodeInteger(forKey: "profileType"))
        let supportsMotion = decoder.decodeBool(forKey: "supportsMotion")
        let controllerType = ControllerType(rawValue: decoder.decodeInteger(forKey: "controllerType"))
        
        self.init(deviceUID: deviceUID, vendorName: vendorName, attachedToDevice: attachedToDevice, profileType: profileType!, controllerType: controllerType!, supportsMotion: supportsMotion)
        
    }
    
    open func encode(with coder: NSCoder) {
        
        coder.encode(self.deviceUID, forKey: "deviceUID")
        coder.encode(self.vendorName, forKey: "vendorName")
        coder.encode(self.attachedToDevice, forKey: "attachedToDevice")
        coder.encode(self.profileType.rawValue, forKey: "profileType")
        coder.encode(self.controllerType.rawValue, forKey: "controllerType")
        coder.encode(self.supportsMotion, forKey: "supportsMotion")
        
    }
    
    // A copy of the deviceInfo object is made when forwarding it through a Bridge.
    //func copy(with zone: NSZone? = nil) -> Any {
    @objc func copyWithZone(_ zone: NSZone?) -> AnyObject {
        let copy = DeviceInfo(deviceUID: deviceUID, vendorName: vendorName, attachedToDevice: attachedToDevice, profileType: profileType, controllerType: controllerType, supportsMotion: supportsMotion)
        return copy
    }
    /*
    func copyWithZone(zone: NSZone) -> AnyObject {
        // This is the reason why `init(_ model: GameModel)`
        // must be required, because `GameModel` is not `final`.
        return self.dynamicType.init(self)
    }
    */
    //public func copy(with zone: NSZone? = nil) -> Any {
    //    return Swift.type(of:self).init(self)
    //}

}
