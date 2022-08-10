//
//  NSObject+PVAbstractAdditions.swift
//  PVSupport
//
//  Created by Joseph Mattiello on 8/10/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation

@objc
public extension NSObject {
    class func doesNotImplementSelector(_ sel: Selector) {
        let exception = NSException(name: .invalidArgumentException, reason: "*** \(sel_getName(sel)) cannot be sent to the abstract class \(type(of: self)): Create a concrete subclass!")
        objc_exception_throw(exception)
    }
    
    func doesNotImplementSelector(_ sel: Selector) {
        let exception = NSException(name: .invalidArgumentException, reason: "*** \(sel_getName(sel)) cannot be sent to the abstract class \(type(of: self)): Create a concrete subclass!")
        objc_exception_throw(exception)
    }
    
    
    class func doesNotImplementOptionalSelector(_ sel: Selector) {
        ELOG("*** + \(sel_getName(sel)) is an optional method and it is not implemented in \(type(of: self))!")
    }
    
    func doesNotImplementOptionalSelector(_ sel: Selector) {
        ELOG("*** + \(sel_getName(sel)) is an optional method and it is not implemented in \(type(of: self))!")
    }
}
