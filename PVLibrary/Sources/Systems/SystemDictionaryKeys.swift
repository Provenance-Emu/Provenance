//
//  SystemDictionaryKeys.swift
//  
//
//  Created by Joseph Mattiello on 6/13/24.
//

import Foundation

public struct SystemDictionaryKeys {
    public static let BIOSEntries = "PVBIOSNames"
    public static let ControlLayout = "PVControlLayout"
    public static let DatabaseID = "PVDatabaseID"
    public static let RequiresBIOS = "PVRequiresBIOS"
    public static let SystemShortName = "PVSystemShortName"
    public static let SupportedExtensions = "PVSupportedExtensions"
    public static let SystemIdentifier = "PVSystemIdentifier"
    public static let SystemName = "PVSystemName"
    public static let Manufacturer = "PVManufacturer"
    public static let Bit = "PVBit"
    public static let ReleaseYear = "PVReleaseYear"
    public static let UsesCDs = "PVUsesCDs"
    public static let SupportsRumble = "PVSupportsRumble"
    public static let ScreenType = "PVScreenType"
    public static let Portable = "PVPortable"

    public struct ControllerLayoutKeys {
        public static let Button = "PVButton"
        public static let ButtonGroup = "PVButtonGroup"
        public static let ControlFrame = "PVControlFrame"
        public static let ControlSize = "PVControlSize"
        public static let ControlTitle = "PVControlTitle"
        public static let ControlTint = "PVControlTint"
        public static let ControlType = "PVControlType"
        public static let DPad = "PVDPad"
        public static let JoyPad = "PVJoyPad"
        public static let JoyPad2 = "PVJoyPad2"
        public static let GroupedButtons = "PVGroupedButtons"
        public static let LeftShoulderButton = "PVLeftShoulderButton"
        public static let RightShoulderButton = "PVRightShoulderButton"
        public static let LeftShoulderButton2 = "PVLeftShoulderButton2"
        public static let RightShoulderButton2 = "PVRightShoulderButton2"
        public static let LeftAnalogButton = "PVLeftAnalogButton"
        public static let RightAnalogButton = "PVRightAnalogButton"
        public static let ZTriggerButton = "PVZTriggerButton"
        public static let SelectButton = "PVSelectButton"
        public static let StartButton = "PVStartButton"
    }
}
