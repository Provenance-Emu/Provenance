//
//  RealTimeThread
//  Provenance
//
//  Created by Joseph Mattiello 01/07/2023.
//

import Foundation
import MachO

@_cdecl("move_pthread_to_realtime_scheduling_class")
public func movePthreadToRealtimeSchedulingClass(_ pthread: pthread_t) {

    
    var timebaseInfo = mach_timebase_info_data_t()
    mach_timebase_info(&timebaseInfo)

    let nanosPerMsec = 1000000.0
    let clock2abs = Double(timebaseInfo.denom) / Double(timebaseInfo.numer) * nanosPerMsec

    var policy = thread_time_constraint_policy()
    policy.period = 0
    policy.computation = UInt32(5 * clock2abs) // 5 ms of work
    policy.constraint = UInt32(10 * clock2abs) // 10 ms of latency
    policy.preemptible = 0 // FALSE


    let THREAD_TIME_CONSTRAINT_POLICY: UInt32 = 2
    let THREAD_TIME_CONSTRAINT_POLICY_COUNT = mach_msg_type_number_t(MemoryLayout<thread_time_constraint_policy>.size / MemoryLayout<integer_t>.size)

    let kr = withUnsafeMutablePointer(to: &policy) { policyPtr in
        return policyPtr.withMemoryRebound(to: integer_t.self, capacity: Int(THREAD_TIME_CONSTRAINT_POLICY_COUNT)) {
            thread_policy_set(pthread_mach_thread_np(pthread), THREAD_TIME_CONSTRAINT_POLICY, $0, THREAD_TIME_CONSTRAINT_POLICY_COUNT)
        }
    }

    if kr != KERN_SUCCESS {
        print("thread_policy_set error:", String(cString: mach_error_string(kr)))
        // exit(1); // Consider how to handle errors in a Swift context
    }
}

@_cdecl("MakeCurrentThreadRealTime") 
public func MakeCurrentThreadRealTime() {
    movePthreadToRealtimeSchedulingClass(pthread_self())
}
