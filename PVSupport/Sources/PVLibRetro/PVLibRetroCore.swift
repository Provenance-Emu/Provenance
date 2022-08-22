//
//  PVLibRetroCore.swift
//  PVSupport
//
//  Created by Joseph Mattiello on 8/22/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation
import PVSupport
import retro

//struct FixedArray<n: Int, T> {
//  var a: Array<T>;
//  init() { a = Array<T>.init(repeating: T.zero, count: n);  }
//}
//
//struct Matrix<T> {
//  var elems: FixedSizeArray<T>
//
//  @guaranteedInline
//  init(rows: Int, columns: Int, initialValue: T) {
//    self.elems = FixedSizeArray(repeating: initialValue, count: rows * columns)
//  }
//}

//struct FixedArray<n: Int, T> {
//    enum FixedArrayError {
//        case indexOutOfBounds
//    }
//
//    var _array: [T]
//    init(_array: [T]) {
//        self._array = _array
//    }
//
//    subscript(key: n.Type) -> T? {
//        get {
//            guard key < n else {
//                throw FixedArrayError.indexOutOfBounds
//            }
//            return _array[key]
//        }
//        set(newValue) {
//            guard key < n else {
//                throw FixedArrayError.indexOutOfBounds
//            }
//            return _array[key]
//        }
//    }
//}

weak var _current: PVLibRetroCore?

var inputStateCallback: retro_input_state_t = { port,device,index,_id in
    guard let strongCurrent = _current else { return }
    var value: Int16 = 0
    if port == 0, device == RETRO_DEVICE_JOYPAD {
        if strongCurrent.controller1 != nil {
            value = strongCurrent.controllerValue(forButtonID: _id, forPlayer: port)
        }
        if value == 0 {
            value = strongCurrent._pad[0][_id]
        }
    }
}

@objc
public class PVLibRetroCore: PVEmulatorCore, KeyboardResponder, MouseResponder, TouchPadResponder {
    var pitch_shift: Int8 = 0
    
    var videoBufferA: UnsafeMutablePointer<UInt16>? = nil
    var videoBufferB: UnsafeMutablePointer<UInt16>? = nil
  
    var _pad = Array<Array<UInt16>>(repeating: Array<UInt16>(repeating: 0, count: 12), count: 2)
//    var _pad = [[UInt16?]](
//     repeating: [UInt16?](repeating: nil, count: 12)
//     count: 2
//    ) // 2-dimension array size 2x12
//
//    var core: retro_core_t? = nil

    // MARK: - Retro Structs
    var core_poll_type: UInt
    var core_input_polled: Bool
    var core_has_set_input_descriptors: Bool
    var av_info: retro_system_av_info?
    var pix_fmt: retro_pixel_format
    
    var supportsAchievements: Bool

    var mouse_x: UInt16
    var mouse_y: UInt16
    var mouse_wheel_up: UInt16
    var mouse_wheel_down: UInt16
    var mouse_horiz_wheel_up: UInt16
    var mouse_horiz_wheel_down: UInt16

    var mouseLeft: Bool
    var mouseRight: Bool
    var mouseMiddle: Bool
    var mouse_button_4: Bool
    var mouse_button_5: Bool
    
    var virtualPhysicalKeyMap: [Int:Int]
    
    public var gameSupportsKeyboard: Bool
    public var requiresKeyboard: Bool
    
    public var keyChangedHandler: GCKeyboardValueChangedHandler?
    
    @available(iOS 14.0, *)
    public func keyDown(_ key: GCKeyCode) {
        
    }
    
    @available(iOS 14.0, *)
    public func keyUp(_ key: GCKeyCode) {
        
    }
    
    public var gameSupportsMouse: Bool {
        return true // TODO: is there a retro check for this?
    }
    
    public var requiresMouse: Bool {
        return false // TODO: is there a retro check for this?
    }
    
    public func didScroll(xValue: Float, yValue: Float) {
        
    }
    
    public var mouseMovedHandler: GCMouseMoved?
    
    public func mouseMoved(atPoint point: CGPoint) {
        
    }
    
    public func leftMouseDown() {
        let status = inputStateCallback(0, UInt32(RETRO_DEVICE_MOUSE), 1, UInt32(RETRO_DEVICE_ID_MOUSE_LEFT))
        VLOG("\(status)")
    }
    
    public func leftMouseUp() {
        let status = inputStateCallback(0, UInt32(RETRO_DEVICE_MOUSE), 1, UInt32(RETRO_DEVICE_ID_MOUSE_LEFT))
        VLOG("\(status)")
    }
    
    public func rightMouseDown() {
        let status = inputStateCallback(0, UInt32(RETRO_DEVICE_MOUSE), 1, UInt32(RETRO_DEVICE_ID_MOUSE_RIGHT))
        VLOG("\(status)")
    }
    
    public func rightMouseUp() {
        let status = inputStateCallback(0, UInt32(RETRO_DEVICE_MOUSE), 1, UInt32(RETRO_DEVICE_ID_MOUSE_RIGHT))
        VLOG("\(status)")
    }
    
    public func middleMouseDown() {
        
    }
    
    public func middleMouseUp() {
        
    }
    
    public func auxiliaryMouseDown() {
        
    }
    
    public func auxiliaryMouseUp() {
        
    }
    
    public func auxiliary2MouseDown() {
        
    }
    
    public func auxiliary2MouseUp() {
        
    }
    
    public var touchedChangedHandler: GCControllerButtonTouchedChangedHandler?
    
    public var pressedChangedHandler: GCControllerButtonValueChangedHandler?
    
    public var valueChangedHandler: GCControllerButtonValueChangedHandler?
    
    public var gameSupportsTouchpad: Bool
}
