//
//  VgcCustomMappings.swift
//  
//
//  Created by Rob Reuss on 10/22/15.
//
//

import Foundation
import VirtualGameController

open class CustomMappings: CustomMappingsSuperclass {
    
    public override init() {
        
        super.init()
        
        ///
        /// CUSTOMIZE HERE
        ///
        /// Use this data structure to map one control element onto another, which means that
        /// both will fire at the same time.
        
        /// Mapping can be performed on either the peripheral side or the central side.
        /// Obviously, central-side mapping is more performant from a network utilization
        /// perspective.  Peripheral-side mapping is more efficient in terms of how it is
        /// performed, but has the  disadvantage of not supporting hardware control mapping,
        /// which central-side mapping does.


        //self.mappings = [
        //    ElementType.RightThumbstickXAxis.rawValue:  ElementType.DpadXAxis.rawValue,
        //    ElementType.DpadXAxis.rawValue:  ElementType.RightThumbstickXAxis.rawValue,
        //
        //]

    }
    
}
