//
//  UIDeviceExtension.swift
//  PVSupport
//
//  Created by Joseph Mattiello on 5/24/18.
//  Copyright © 2018 Provenance. All rights reserved.
//

import Foundation

public extension UIDevice {

	/// pares the deveice name as the standard name
	@objc
	var modelName: String {

		#if targetEnvironment(simulator)
		let identifier = ProcessInfo().environment["SIMULATOR_MODEL_IDENTIFIER"]!
		#else
		var systemInfo = utsname()
		uname(&systemInfo)
		let machineMirror = Mirror(reflecting: systemInfo.machine)
		let identifier = machineMirror.children.reduce("") { identifier, element in
			guard let value = element.value as? Int8, value != 0 else { return identifier }
			return identifier + String(UnicodeScalar(UInt8(value)))
		}
		#endif

		switch identifier {
		case "iPod5,1":                                 return "iPod Touch 5"
		case "iPod7,1":                                 return "iPod Touch 6"
		case "iPhone3,1", "iPhone3,2", "iPhone3,3":     return "iPhone 4"
		case "iPhone4,1":                               return "iPhone 4s"
		case "iPhone5,1", "iPhone5,2":                  return "iPhone 5"
		case "iPhone5,3", "iPhone5,4":                  return "iPhone 5c"
		case "iPhone6,1", "iPhone6,2":                  return "iPhone 5s"
		case "iPhone7,2":                               return "iPhone 6"
		case "iPhone7,1":                               return "iPhone 6 Plus"
		case "iPhone8,1":                               return "iPhone 6s"
		case "iPhone8,2":                               return "iPhone 6s Plus"
		case "iPhone9,1", "iPhone9,3":                  return "iPhone 7"
		case "iPhone9,2", "iPhone9,4":                  return "iPhone 7 Plus"
		case "iPhone8,4":                               return "iPhone SE"
		case "iPhone10,1", "iPhone10,4":                return "iPhone 8"
		case "iPhone10,2", "iPhone10,5":                return "iPhone 8 Plus"
		case "iPhone10,3", "iPhone10,6":                return "iPhone X"
		case "iPad2,1", "iPad2,2", "iPad2,3", "iPad2,4":return "iPad 2"
		case "iPad3,1", "iPad3,2", "iPad3,3":           return "iPad 3"
		case "iPad3,4", "iPad3,5", "iPad3,6":           return "iPad 4"
		case "iPad4,1", "iPad4,2", "iPad4,3":           return "iPad Air"
		case "iPad5,3", "iPad5,4":                      return "iPad Air 2"
		case "iPad6,11", "iPad6,12":                    return "iPad 5"
		case "iPad2,5", "iPad2,6", "iPad2,7":           return "iPad Mini"
		case "iPad4,4", "iPad4,5", "iPad4,6":           return "iPad Mini 2"
		case "iPad4,7", "iPad4,8", "iPad4,9":           return "iPad Mini 3"
		case "iPad5,1", "iPad5,2":                      return "iPad Mini 4"
		case "iPad6,3", "iPad6,4":                      return "iPad Pro 9.7 Inch"
		case "iPad6,7", "iPad6,8":                      return "iPad Pro 12.9 Inch"
		case "iPad7,1", "iPad7,2":                      return "iPad Pro 12.9 Inch 2. Generation"
		case "iPad7,3", "iPad7,4":                      return "iPad Pro 10.5 Inch"
		case "AppleTV5,3":                              return "Apple TV"
		case "AppleTV6,2":                              return "Apple TV 4K"
		case "AudioAccessory1,1":                       return "HomePod"
		default:                                        return identifier
		}
	}
}
