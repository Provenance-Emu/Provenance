//
//  Thread+RealTime.swift
//  PVSupport
//
//  Created by Joseph Mattiello on 8/10/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation
import Darwin.Mach

private let machToSeconds: Double = {
    var base = mach_timebase_info()
    mach_timebase_info(&base)
    return 1e-9 * Double(base.numer) / Double(base.denom)
}()

@objc
public extension Thread
{
    class var absoluteSystemTime: TimeInterval {
        return Double(mach_absolute_time()) * machToSeconds;
    }
    
    @discardableResult @objc
    class func setRealTimePriority() -> Bool {
        return setRealTimePriority(withPeriod: .init(floatLiteral: 1.0 / 60.0))
    }
    
    @discardableResult
    class func setRealTimePriority(withPeriod period: TimeInterval) -> Bool {
        var policy = thread_time_constraint_policy()
        policy.period = UInt32(period / machToSeconds)
        policy.computation = UInt32(0.007 / machToSeconds)
        policy.constraint = UInt32(0.03 / machToSeconds)
        policy.preemptible = 0
        
        let threadport = pthread_mach_thread_np(pthread_self())
        let count = mach_msg_type_number_t(MemoryLayout<thread_time_constraint_policy_data_t>.size / MemoryLayout<integer_t>.size)
        
        var result = KERN_SUCCESS
        
        withUnsafePointer(to: &policy) { (pointer) in
            pointer.withMemoryRebound(to: integer_t.self, capacity: 1) { (policyPointer) in
                let mutablePolicyPointer = UnsafeMutablePointer(mutating: policyPointer)
                result = thread_policy_set(threadport, UInt32(THREAD_TIME_CONSTRAINT_POLICY), mutablePolicyPointer, count)
            }
        }
        
        if result != KERN_SUCCESS
        {
            ELOG("Thread.setRealTimePriority(withPeriod:) failed.")
            return false
        }
        
        return true
    }
    
    class func realTimeWait(until targetTime: TimeInterval) {
        mach_wait_until(UInt64(targetTime / machToSeconds))
    }
}
