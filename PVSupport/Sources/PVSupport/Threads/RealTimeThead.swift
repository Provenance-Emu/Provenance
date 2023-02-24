//
//  RealTimeThread
//  Provenance
//
//  Created by Joseph Mattiello 01/07/2023.
//

import Foundation
import MachO

public func move_pthread_to_realtime_scheduling_class(_ pthread: pthread_t) {
    // let timebase_info = mach_timebase_info_data_t()
    // mach_timebase_info(&timebase_info)

    // let NANOS_PER_MSEC: UInt64 = 1000000
    // let clock2abs = (timebase_info.denom / timebase_info.numer) * NANOS_PER_MSEC

    // var policy = thread_time_constraint_policy_data_t()
    // policy.period = 0
    // policy.computation = UInt32(5 * clock2abs) // 5 ms of work
    // policy.constraint = UInt32(10 * clock2abs) // 10 ms of latency
    // policy.preemptible = false

    // let kr = thread_policy_set( pthread_mach_thread_np(pthread),
    //                             thread_policy_flavor_t(THREAD_TIME_CONSTRAINT_POLICY),
    //                             thread_policy_t(&policy),
    //                             thread_policy_flavor_t(THREAD_TIME_CONSTRAINT_POLICY_COUNT))
    // if kr != KERN_SUCCESS {
    //     print("Failed to set thread policy: \(kr)")
    //     mach_error("thread_policy_set:", kr)
    //     // exit(1)
    // }
}

@_cdecl("MakeCurrentThreadRealTime") public func MakeCurrentThreadRealTime() {
    move_pthread_to_realtime_scheduling_class(pthread_self())
}
