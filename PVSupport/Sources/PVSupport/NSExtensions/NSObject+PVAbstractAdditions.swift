//
//  NSObject+PVAbstractAdditions.swift
//  
//
//  Created by Joseph Mattiello on 5/15/22.
//

import Foundation

// PVAbstractAdditions
@objc
public protocol PVAbstractAdditions: NSObjectProtocol {
    class func doesNotImplementSelector(aSel: Selector)
    class func doesNotImplementOptionalSelector(aSel: Selector)

    func doesNotImplementSelector(aSel: Selector)
    func doesNotImplementOptionalSelector(aSel: Selector)
}

@objc
public extension NSObject: PVAbstractAdditions {
    class func doesNotImplementSelector(aSel: Selector) {
//        @throw [NSException exceptionWithName:NSInvalidArgumentException
//                                       reason:[NSString stringWithFormat:@"*** +%s cannot be sent to the abstract class %@: Create a concrete subclass!", sel_getName(aSel), [self class]]
//                                     userInfo:nil];

    }
    class func doesNotImplementOptionalSelector(aSel: Selector) {
//        ELOG(@"*** +%s is an optional method and it is not implemented in %@!", sel_getName(aSel), NSStringFromClass([self class]));
    }

    func doesNotImplementSelector(aSel: Selector) {
        //        NSString* reason = [NSString stringWithFormat:@"*** -%s cannot be sent to an abstract object of class %@: Create a concrete instance!", sel_getName(aSel), [self class]];
        //        ELOG(@"%@", reason);
        //        @throw [NSException exceptionWithName:NSInvalidArgumentException
        //                                       reason:reason
        //                                     userInfo:nil];
    }
    func doesNotImplementOptionalSelector(aSel: Selector) {
//        ELOG(@"*** -%s is an optional method and it is not implemented in %@!", sel_getName(aSel), NSStringFromClass([self class]));
    }
}
