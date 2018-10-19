//
//  VgcElement.swift
//
//
//  Created by Rob Reuss on 10/1/15.
//
//

import Foundation

#if os(iOS) || os(OSX) || os(tvOS)
    import GameController
#endif

#if os(iOS) || os(watchOS) || os(tvOS)
    import UIKit
#endif

public enum SystemMessages: Int, CustomStringConvertible {
    
    case connectionAcknowledgement = 100
    case disconnect = 101
    case receivedInvalidMessage = 102
    
    public var description : String {
        
        switch self {
        case .connectionAcknowledgement: return "ConnectionAcknowledgement"
        case .disconnect: return "Disconnect"
        case .receivedInvalidMessage: return "Received invalid message"
            
        }
    }
}

// The type of data that will be sent for a given
// element.
@objc public enum ElementDataType: Int {
    
    case Int
    case Float
    case Double
    case String
    case Data
    
}

// The type of data that will be sent for a given
// element.
public enum StreamDataType: Int, CustomStringConvertible {
    
    case smallData
    case largeData
    
    public var description : String {
        
        switch self {
        case .smallData: return "Small Data"
        case .largeData: return "Large Data"
            
        }
    }
}

// The whole population of system and standard elements

@objc public enum ElementType: Int {
    
    case deviceInfoElement
    case systemMessage
    case playerIndex
    case peripheralSetup
    case vibrateDevice
    case image
    
    // .Standard elements
    case pauseButton
    case leftShoulder
    case rightShoulder
    case dpadXAxis
    case dpadYAxis
    case buttonA
    case buttonB
    case buttonX
    case buttonY
    case leftThumbstickXAxis
    case leftThumbstickYAxis
    case rightThumbstickXAxis
    case rightThumbstickYAxis
    case leftTrigger
    case rightTrigger
    
    // Motion elements
    case motionUserAccelerationX
    case motionUserAccelerationY
    case motionUserAccelerationZ
    
    case motionAttitudeX
    case motionAttitudeY
    case motionAttitudeZ
    case motionAttitudeW
    
    case motionRotationRateX
    case motionRotationRateY
    case motionRotationRateZ
    
    case motionGravityX
    case motionGravityY
    case motionGravityZ
    
    // Custom
    case custom
    
}

// Message header identifier is a random pre-generated 32-bit integer
let headerIdentifierAsNSData = Data(bytes: &VgcManager.headerIdentifier, count: MemoryLayout<UInt32>.size)

///
/// Element is a class that represents each element/control on a controller, such as Button A or dpad.
/// Along with describing the controller element in terms of name and data type,and providing a
/// unique identifier used when transmitting values, an element functions as the backing store that
/// allows for multiple profiles to share the same underlying data set.  For example, because the Gamepad
/// profile is a subset of the Extended Gamepad, the element provides the basis for providing access to
/// values through both profile interfaces for the same controller.
///
/// - parameter type: ElementType enumerates the standard set of controller elements, plus a few system-
/// related elements, DeviceInfoElement, SystemMessage and Custom.
/// - parameter dataType: Currently three data types are supported, .String, .Int, and .Float, enumerated
/// in ElementDataType.
/// - parameter name: Human-readable name for the element.
/// - parameter value: The canonical value for the element.
/// - parameter getterKeypath: Path to the VgcController class interface for getting the value of the element.
/// - parameter setterKeypath: Path to the VgcController class interface for triggering the developer-defined
/// handlers for the element.
/// - parameter identifier: A unique integer indentifier used to identify the element a value belongs to
/// when transmitting the value over the network.
/// - parameter mappingComplete: A state management value used as a part of the peripheral-side element mapping system.
///
open class Element: NSObject {
    
    @objc open var type: ElementType
    @objc open var dataType: ElementDataType
    
    @objc open var name: String
    @objc open var value: AnyObject
    @objc open var getterKeypath: String
    @objc open var setterKeypath: String
    
    /// Automatically clear out value after transfering
    @objc open var clearValueAfterTransfer: Bool = false
    
    // Unique identifier is based on the element type
    open var identifier: Int!
    
    // Used only for custom elements
    #if !os(watchOS)
    public typealias VgcCustomElementValueChangedHandler = (VgcController, Element) -> Void
    @objc open var valueChangedHandler: VgcCustomElementValueChangedHandler!
    #endif
    
    public typealias VgcCustomProfileValueChangedHandlerForPeripheral = (Element) -> Void
    @objc open var valueChangedHandlerForPeripheral: VgcCustomProfileValueChangedHandlerForPeripheral!
    
    // Used as a flag when peripheral-side mapping one element to another, to prevent recursion
    var mappingComplete: Bool!
    
    #if os(iOS) || os(OSX) || os(tvOS)
    
    // Make class hashable - function to make it equatable appears below outside the class definition
    open override var hashValue: Int {
        return type.hashValue
    }
    #endif
    
    // Init for a standard (not custom) element
    @objc public init(type: ElementType, dataType: ElementDataType,  name: String, getterKeypath: String, setterKeypath: String) {
        
        self.type = type
        self.dataType = dataType
        self.name = name
        self.value = Float(0.0) as AnyObject
        self.mappingComplete = false
        self.getterKeypath = getterKeypath
        self.setterKeypath = setterKeypath
        self.identifier = type.rawValue
        
        super.init()
    }
    
    @objc open func clearValue() {
        switch self.dataType {
            
        case .Int:
            value = 0 as AnyObject
            
        case .Float:
            value = 0.0 as AnyObject
            
        case .Double:
            value = 0.0 as AnyObject
            
        case .Data:
            value = Data() as AnyObject
            
        case .String:
            value = "" as AnyObject
        }
    }
    
    @objc open var dataMessage: NSMutableData {
        
        let elementValueAsNSData = valueAsNSData
        
        var elementIdentifierAsUInt8: UInt8 = UInt8(identifier)
        let elementIdentifierAsNSData = Data(bytes: &elementIdentifierAsUInt8, count: MemoryLayout<UInt8>.size)
        
        var valueLengthAsUInt32: UInt32 = UInt32(elementValueAsNSData.count)
        let valueLengthAsNSData = Data(bytes: &valueLengthAsUInt32, count: MemoryLayout<UInt32>.size)
        
        let messageData = NSMutableData()
        
        // Message header
        messageData.append(headerIdentifierAsNSData)  // 4 bytes:   indicates the start of an individual message, random 32-bit int
        messageData.append(elementIdentifierAsNSData) // 1 byte:    identifies the type of the element
        messageData.append(valueLengthAsNSData)       // 4 bytes:   length of the message
        
        
        if VgcManager.netServiceLatencyLogging {                   // 8 bytes:  For latency testing
            
            var timestamp: Double = Date().timeIntervalSince1970
            let timestampAsNSData = Data(bytes: &timestamp, count: MemoryLayout<Double>.size)
            messageData.append(timestampAsNSData)
            
        }
            
        // Body of message
        messageData.append(elementValueAsNSData)      // Variable:  the message itself, 4 for Floats, 4 for Int, variable for NSData
        
        return messageData
    }
    
    @objc open var valueAsNSData: Data {
        
        get {

            switch self.dataType {
                
            case .Int:
                
                var value: Int = self.value as! Int
                let data = NSData(bytes: &value, length: MemoryLayout<Int>.size)
                return data as Data
                
            case .Float:
                
                var value: Float = self.value as! Float
                let data = NSData(bytes: &value, length: MemoryLayout<Float>.size)
                return data as Data
                
            case .Double:
                
                var value: Double = self.value as! Double
                let data = NSData(bytes: &value, length: MemoryLayout<Double>.size)
                return data as Data
      
            case .Data:
                return self.value as! Data
                
            case .String:
                if let myData = (self.value as! String).data(using: String.Encoding.utf8) {
                    return (NSData(data: myData) as Data)
                } else {
                    vgcLogError("Got nil when expecting string data")
                    return Data()
                }
            }
        }
        
        set {
            switch self.dataType {
                
            case .Int:

                let data: NSData = newValue as NSData
                var tempFloat: Int = 0
                data.getBytes(&tempFloat, length: MemoryLayout<Int>.size)
                self.value = tempFloat as AnyObject
                
            case .Float:
                
                let data: NSData = newValue as NSData
                var tempFloat: Float = 0
                data.getBytes(&tempFloat, length: MemoryLayout<Float>.size)
                self.value = tempFloat as AnyObject
                
            case .Double:
                
                let data: NSData = newValue as NSData
                var tempFloat: Double = 0
                data.getBytes(&tempFloat, length: MemoryLayout<Double>.size)
                self.value = tempFloat as AnyObject
                
            case .Data:
                self.value = newValue as AnyObject
                
            case .String:
                self.value = String(data: newValue, encoding: String.Encoding.utf8)! as AnyObject
                
            }
        }
    }
    
    #if os(iOS) || os(OSX) || os(tvOS)
       
    // Provides calculated keypaths for access to game controller elements
    
    open func getterKeypath(_ controller: VgcController) -> String {
        
        switch (type) {
            
        case .systemMessage, .playerIndex, .pauseButton, .deviceInfoElement, .peripheralSetup, .vibrateDevice, .image: return ""
            
        case .motionAttitudeX, .motionAttitudeW, .motionAttitudeY, .motionAttitudeZ, .motionGravityX, .motionGravityY, .motionGravityZ, .motionRotationRateX, .motionRotationRateY, .motionRotationRateZ, .motionUserAccelerationX, .motionUserAccelerationY, .motionUserAccelerationZ:
            
            return "motion." + getterKeypath
            
        default: return controller.profileType.pathComponentRead + "." + getterKeypath
        }
        
    }
    open func setterKeypath(_ controller: VgcController) -> String {
        
        switch (type) {
        case .systemMessage, .playerIndex, .deviceInfoElement, .peripheralSetup, .vibrateDevice, .image: return ""
        case .motionAttitudeX, .motionAttitudeW, .motionAttitudeY, .motionAttitudeZ, .motionGravityX, .motionGravityY, .motionGravityZ, .motionRotationRateX, .motionRotationRateY, .motionRotationRateZ, .motionUserAccelerationX, .motionUserAccelerationY, .motionUserAccelerationZ:
            
            return "motion." + setterKeypath
        default: return controller.profileType.pathComponentWrite + "." + setterKeypath
        }
    }
    
    required convenience public init(coder decoder: NSCoder) {
        
        let type = ElementType(rawValue: decoder.decodeInteger(forKey: "type"))!
        let dataType = ElementDataType(rawValue: decoder.decodeInteger(forKey: "type"))!
        let name = decoder.decodeObject(forKey: "name") as! String
        let getterKeypath = decoder.decodeObject(forKey: "getterKeypath") as! String
        let setterKeypath = decoder.decodeObject(forKey: "setterKeypath") as! String
        
        self.init(type: type, dataType: dataType,  name: name, getterKeypath: getterKeypath, setterKeypath: setterKeypath)
        
    }
    
    open func encodeWithCoder(_ coder: NSCoder) {
    
        coder.encode(type.rawValue, forKey: "type")
        coder.encode(dataType.rawValue, forKey: "dataType")
        coder.encode(name, forKey: "name")
        coder.encode(getterKeypath, forKey: "getterKeypath")
        coder.encode(setterKeypath, forKey: "setterKeypath")
    
    }
    
    #endif

    @objc func clone() -> Element {
        let clone = Element(type: type, dataType: dataType,  name: name, getterKeypath: getterKeypath, setterKeypath: setterKeypath)
        return clone
    }

}

#if os(iOS) || os(OSX) || os(tvOS)
    // Make class equatable
    func ==(lhs: Element, rhs: Element) -> Bool {
        return lhs.type.hashValue == rhs.type.hashValue
    }
#endif

///
/// The Elements class describes the full population of controller controls, as well as
/// providing definitions of the population of elements for each profile type.
///
open class Elements: NSObject {
    
    override init() {
        
        systemElements = []
        systemElements.append(systemMessage)
        systemElements.append(deviceInfoElement)
        systemElements.append(pauseButton)
        systemElements.append(peripheralSetup)
        systemElements.append(vibrateDevice)
        systemElements.append(image)
        
        motionProfileElements = []
        motionProfileElements.append(motionUserAccelerationX)
        motionProfileElements.append(motionUserAccelerationY)
        motionProfileElements.append(motionUserAccelerationZ)
        motionProfileElements.append(motionRotationRateX)
        motionProfileElements.append(motionRotationRateY)
        motionProfileElements.append(motionRotationRateZ)
        motionProfileElements.append(motionAttitudeX)
        motionProfileElements.append(motionAttitudeY)
        motionProfileElements.append(motionAttitudeZ)
        motionProfileElements.append(motionAttitudeW)
        motionProfileElements.append(motionGravityX)
        motionProfileElements.append(motionGravityY)
        motionProfileElements.append(motionGravityZ)
        
        
        // MicroGamepad profile element collection
        microGamepadProfileElements = []
        microGamepadProfileElements.append(pauseButton)
        microGamepadProfileElements.append(playerIndex)
        microGamepadProfileElements.append(dpadXAxis)
        microGamepadProfileElements.append(dpadYAxis)
        microGamepadProfileElements.append(buttonA)
        microGamepadProfileElements.append(buttonX)
        
        
        // Gamepad profile element collection
        gamepadProfileElements = []
        gamepadProfileElements.append(pauseButton)
        gamepadProfileElements.append(playerIndex)
        gamepadProfileElements.append(leftShoulder)
        gamepadProfileElements.append(rightShoulder)
        gamepadProfileElements.append(dpadXAxis)
        gamepadProfileElements.append(dpadYAxis)
        gamepadProfileElements.append(buttonA)
        gamepadProfileElements.append(buttonB)
        gamepadProfileElements.append(buttonX)
        gamepadProfileElements.append(buttonY)
        
        // Extended profile element collection
        extendedGamepadProfileElements = []
        extendedGamepadProfileElements.append(pauseButton)
        extendedGamepadProfileElements.append(playerIndex)
        extendedGamepadProfileElements.append(leftShoulder)
        extendedGamepadProfileElements.append(rightShoulder)
        extendedGamepadProfileElements.append(rightTrigger)
        extendedGamepadProfileElements.append(leftTrigger)
        extendedGamepadProfileElements.append(dpadXAxis)
        extendedGamepadProfileElements.append(dpadYAxis)
        extendedGamepadProfileElements.append(buttonA)
        extendedGamepadProfileElements.append(buttonB)
        extendedGamepadProfileElements.append(buttonX)
        extendedGamepadProfileElements.append(buttonY)
        extendedGamepadProfileElements.append(leftThumbstickXAxis)
        extendedGamepadProfileElements.append(leftThumbstickYAxis)
        extendedGamepadProfileElements.append(rightThumbstickXAxis)
        extendedGamepadProfileElements.append(rightThumbstickYAxis)
        
        // Watch profile element collection
        watchProfileElements = []
        watchProfileElements.append(pauseButton)
        watchProfileElements.append(playerIndex)
        watchProfileElements.append(leftShoulder)
        watchProfileElements.append(rightShoulder)
        watchProfileElements.append(rightTrigger)
        watchProfileElements.append(leftTrigger)
        watchProfileElements.append(dpadXAxis)
        watchProfileElements.append(dpadYAxis)
        watchProfileElements.append(buttonA)
        watchProfileElements.append(buttonB)
        watchProfileElements.append(buttonX)
        watchProfileElements.append(buttonY)
        watchProfileElements.append(leftThumbstickXAxis)
        watchProfileElements.append(leftThumbstickYAxis)
        watchProfileElements.append(rightThumbstickXAxis)
        watchProfileElements.append(rightThumbstickYAxis)
        
        // Iterate the set to set the identifier and load up the hash
        // used by devs to access the elements
        
        if (Elements.customElements != nil) {
            for customElement in Elements.customElements.customProfileElements {
                let elementCopy = customElement.clone()
                elementCopy.identifier = customElement.identifier
                custom[elementCopy.identifier] = elementCopy
                customProfileElements.append(elementCopy)
            }
        }
        
        super.init()
        
        for element in systemElements {
            elementsByHashValue.updateValue(element, forKey: element.identifier)
        }
        
        // Create lookup for getting element based on hash value
        for element in allElementsCollection() {
            elementsByHashValue.updateValue(element, forKey: element.identifier)
        }
        
    }
    
    @objc var systemElements: [Element]
    @objc var extendedGamepadProfileElements: [Element]
    @objc var gamepadProfileElements: [Element]
    @objc var microGamepadProfileElements: [Element]
    @objc var motionProfileElements: [Element]
    @objc open var watchProfileElements: [Element]
    fileprivate var elementsByHashValue = Dictionary<Int, Element>()
    
    @objc open static var customElements: CustomElementsSuperclass!
    @objc open static var customMappings: CustomMappingsSuperclass!
    
    @objc open var custom = Dictionary<Int, Element>()
    @objc open var customProfileElements = [Element]()
    
    @objc open func allElementsCollection() -> [Element] {
        
        let myAll = systemElements + extendedGamepadProfileElements + motionProfileElements + customProfileElements
        return myAll
        
    }
    
    #if !os(watchOS)
    open func elementsForController(_ controller: VgcController) -> [Element] {
        
        var supplemental: [Element] = []
        if controller.deviceInfo.supportsMotion { supplemental = motionProfileElements }
        
        // Get the controller-specific set of custom elements so they contain the
        // current values for the elements
        let customElements = controller.elements.custom.values
//        let customElements: [Element] = controller.custom.values
        supplemental = supplemental + customElements
        
        supplemental.insert(systemMessage, at: 0)
        
        switch(controller.profileType) {
        case .MicroGamepad:
            return microGamepadProfileElements + supplemental
        case .Gamepad:
            return gamepadProfileElements + supplemental
        case .ExtendedGamepad:
            return extendedGamepadProfileElements + supplemental
        default:
            return extendedGamepadProfileElements + supplemental
        }
        
    }
    #endif
    
    @objc open var systemMessage: Element = Element(type: .systemMessage, dataType: .Int, name: "System Messages", getterKeypath: "", setterKeypath: "")
    @objc open var deviceInfoElement: Element = Element(type: .deviceInfoElement, dataType: .Data, name: "Device Info", getterKeypath: "", setterKeypath: "")
    @objc open var playerIndex: Element = Element(type: .playerIndex, dataType: .Int, name: "Player Index", getterKeypath: "playerIndex", setterKeypath: "playerIndex")
    @objc open var pauseButton: Element = Element(type: .pauseButton, dataType: .Float, name: "Pause Button", getterKeypath: "vgcPauseButton", setterKeypath: "vgcPauseButton")
    @objc open var peripheralSetup: Element = Element(type: .peripheralSetup, dataType: .Data, name: "Peripheral Setup", getterKeypath: "", setterKeypath: "")
    @objc open var vibrateDevice: Element = Element(type: .vibrateDevice, dataType: .Int, name: "Vibrate Device", getterKeypath: "", setterKeypath: "")
    @objc open var image: Element = Element(type: .image, dataType: .Data, name: "Send Image", getterKeypath: "image.value", setterKeypath: "image.value")
    
    @objc open var leftShoulder: Element = Element(type: .leftShoulder, dataType: .Float, name: "Left Shoulder", getterKeypath: "leftShoulder.value", setterKeypath: "leftShoulder.value")
    @objc open var rightShoulder: Element = Element(type: .rightShoulder, dataType: .Float, name: "Right Shoulder", getterKeypath: "rightShoulder.value", setterKeypath: "rightShoulder.value")
    
    @objc open var dpadXAxis: Element = Element(type: .dpadXAxis, dataType: .Float, name: "dpad X", getterKeypath: "dpad.xAxis.value", setterKeypath: "dpad.xAxis.value")
    @objc open var dpadYAxis: Element = Element(type: .dpadYAxis, dataType: .Float, name: "dpad Y", getterKeypath: "dpad.yAxis.value", setterKeypath: "dpad.yAxis.value")
    
    @objc open var buttonA: Element = Element(type: .buttonA, dataType: .Float, name: "A", getterKeypath: "buttonA.value", setterKeypath: "buttonA.value")
    @objc open var buttonB: Element = Element(type: .buttonB, dataType: .Float, name: "B", getterKeypath: "buttonB.value", setterKeypath: "buttonB.value")
    @objc open var buttonX: Element = Element(type: .buttonX, dataType: .Float, name: "X", getterKeypath: "buttonX.value", setterKeypath: "buttonX.value")
    @objc open var buttonY: Element = Element(type: .buttonY, dataType: .Float, name: "Y", getterKeypath: "buttonY.value", setterKeypath: "buttonY.value")
    
    @objc open var leftThumbstickXAxis: Element = Element(type: .leftThumbstickXAxis, dataType: .Float, name: "Left Thumb X", getterKeypath: "leftThumbstick.xAxis.value", setterKeypath: "leftThumbstick.xAxis.value")
    @objc open var leftThumbstickYAxis: Element = Element(type: .leftThumbstickYAxis, dataType: .Float, name: "Left Thumb Y", getterKeypath: "leftThumbstick.yAxis.value", setterKeypath: "leftThumbstick.yAxis.value")
    @objc open var rightThumbstickXAxis: Element = Element(type: .rightThumbstickXAxis, dataType: .Float, name: "Right Thumb X", getterKeypath: "rightThumbstick.xAxis.value", setterKeypath: "rightThumbstick.xAxis.value")
    @objc open var rightThumbstickYAxis: Element = Element(type: .rightThumbstickYAxis, dataType: .Float, name: "Right Thumb Y", getterKeypath: "rightThumbstick.yAxis.value", setterKeypath: "rightThumbstick.yAxis.value")
    
    @objc open var rightTrigger: Element = Element(type: .rightTrigger, dataType: .Float, name: "Right Trigger", getterKeypath: "rightTrigger.value", setterKeypath: "rightTrigger.value")
    @objc open var leftTrigger: Element = Element(type: .leftTrigger, dataType: .Float, name: "Left Trigger", getterKeypath: "leftTrigger.value", setterKeypath: "leftTrigger.value")
    
    @objc open var motionUserAccelerationX: Element = Element(type: .motionUserAccelerationX, dataType: .Double, name: "Accelerometer X", getterKeypath: "motionUserAccelerationX", setterKeypath: "motionUserAccelerationX")
    @objc open var motionUserAccelerationY: Element = Element(type: .motionUserAccelerationY, dataType: .Double, name: "Accelerometer Y", getterKeypath: "motionUserAccelerationY", setterKeypath: "motionUserAccelerationY")
    @objc open var motionUserAccelerationZ: Element = Element(type: .motionUserAccelerationZ, dataType: .Double, name: "Accelerometer Z", getterKeypath: "motionUserAccelerationZ", setterKeypath: "motionUserAccelerationZ")
    
    @objc open var motionRotationRateX: Element = Element(type: .motionRotationRateX, dataType: .Double, name: "Rotation Rate X", getterKeypath: "motionRotationRateX", setterKeypath: "motionRotationRateX")
    @objc open var motionRotationRateY: Element = Element(type: .motionRotationRateY, dataType: .Double, name: "Rotation Rate Y", getterKeypath: "motionRotationRateY", setterKeypath: "motionRotationRateY")
    @objc open var motionRotationRateZ: Element = Element(type: .motionRotationRateZ, dataType: .Double, name: "Rotation Rate Z", getterKeypath: "motionRotationRateZ", setterKeypath: "motionRotationRateZ")
    
    @objc open var motionGravityX: Element = Element(type: .motionGravityX, dataType: .Double, name: "Gravity X", getterKeypath: "motionGravityX", setterKeypath: "motionGravityX")
    @objc open var motionGravityY: Element = Element(type: .motionGravityY, dataType: .Double, name: "Gravity Y", getterKeypath: "motionGravityY", setterKeypath: "motionGravityY")
    @objc open var motionGravityZ: Element = Element(type: .motionGravityZ, dataType: .Double, name: "Gravity Z", getterKeypath: "motionGravityZ", setterKeypath: "motionGravityZ")
    
    @objc open var motionAttitudeX: Element = Element(type: .motionAttitudeX, dataType: .Double, name: "Attitude X", getterKeypath: "motionAttitudeX", setterKeypath: "motionAttitudeX")
    @objc open var motionAttitudeY: Element = Element(type: .motionAttitudeY, dataType: .Double, name: "Attitude Y", getterKeypath: "motionAttitudeY", setterKeypath: "motionAttitudeY")
    @objc open var motionAttitudeZ: Element = Element(type: .motionAttitudeZ, dataType: .Double, name: "Attitude Z", getterKeypath: "motionAttitudeZ", setterKeypath: "motionAttitudeZ")
    @objc open var motionAttitudeW: Element = Element(type: .motionAttitudeW, dataType: .Double, name: "Attitude W", getterKeypath: "motionAttitudeW", setterKeypath: "motionAttitudeW")
    
    // Convience functions for getting a controller element object based on specific properties of the
    // controller element

    
    @objc open func elementFromType(_ type: ElementType) -> Element! {
        
        for element in allElementsCollection() {
            if element.type == type { return element }
        }
        return nil
        
    }
    
    @objc open func elementFromIdentifier(_ identifier: Int) -> Element! {
        
        guard let element = elementsByHashValue[identifier] else { return nil }
        return element
        
    }
}

// Convienance initializer, simplifies creation of custom elements
open class CustomElement: Element {
    
    // Init for a custom element
    @objc public init(name: String, dataType: ElementDataType, type: Int) {
        
        super.init(type: .custom , dataType: dataType, name: name, getterKeypath: "", setterKeypath: "")
        
        identifier = type
        
    }
    
    @objc required convenience public init(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}

// A stub, to support creation of a custom mappings class external to a framework
open class CustomMappingsSuperclass: NSObject {
    
    @objc open var mappings = Dictionary<Int, Int>()
    public override init() {
        
        super.init()
        
    }
    
}

// A stub, to support creation of a custom elements class external to a framework
open class CustomElementsSuperclass: NSObject {
    
    // Custom profile-level handler
    // Watch OS implementation does not include VgcController because it does not support parent class GCController
    #if !os(watchOS)
    public typealias VgcCustomProfileValueChangedHandler = (VgcController, Element) -> Void
    @objc open var valueChangedHandler: VgcCustomProfileValueChangedHandler!
    #endif
    
    @objc open var customProfileElements: [Element] = []
    
    public override init() {
        
        super.init()
    }
    
}
