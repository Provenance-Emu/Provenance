//
//  StartSelectDelegate.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/10/24.
//

public protocol StartSelectDelegate: AnyObject {
	func pressStart(forPlayer player: Int)
	func releaseStart(forPlayer player: Int)
	func pressSelect(forPlayer player: Int)
	func releaseSelect(forPlayer player: Int)
	func pressAnalogMode(forPlayer player: Int)
	func releaseAnalogMode(forPlayer player: Int)
	func pressL3(forPlayer player: Int)
	func releaseL3(forPlayer player: Int)
	func pressR3(forPlayer player: Int)
	func releaseR3(forPlayer player: Int)
}
