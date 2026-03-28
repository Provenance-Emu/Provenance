//
//  PerfInterfaceTests.swift
//  PVLibRetroTests
//
//  Tests for the libretro performance interface (RETRO_ENVIRONMENT_GET_PERF_INTERFACE).
//  Exercises the C callback implementations defined in PVThinLibretroFrontend.mm:
//  timing, CPU feature detection, counter registration, start/stop accumulation, and logging.
//
//  NOTE: pv_perf_register uses a process-global static array that cannot be
//  reset between tests. Each test uses fresh retro_perf_counter structs and
//  does not assert on exact counter counts. Counters that will remain
//  referenced by the global array after registration are heap-allocated
//  to avoid dangling pointers.
//

import Testing
@testable import libretro
@testable import PVLibRetro

/// Helper: allocate a heap-backed retro_perf_counter with a static ident string.
/// Heap allocation ensures the pointer stored in the global perf counter array
/// remains valid for the process lifetime (matching real-world libretro usage
/// where counters are file-scope statics).
private func makeCounter(_ ident: StaticString) -> UnsafeMutablePointer<retro_perf_counter> {
    let ptr = UnsafeMutablePointer<retro_perf_counter>.allocate(capacity: 1)
    ptr.initialize(to: retro_perf_counter())
    ptr.pointee.ident = UnsafeRawPointer(ident.utf8Start)
        .assumingMemoryBound(to: CChar.self)
    return ptr
}

// MARK: - Timing tests

struct PerfTimingTests {

    /// pv_perf_get_time_usec must return a positive value (time since boot in microseconds).
    @Test func getTimeUsec_returnsPositive() {
        let t = pv_perf_get_time_usec()
        #expect(t > 0, "Expected positive microsecond timestamp, got \(t)")
    }

    /// Two successive calls must be monotonically non-decreasing.
    @Test func getTimeUsec_isMonotonic() {
        let t1 = pv_perf_get_time_usec()
        let t2 = pv_perf_get_time_usec()
        #expect(t2 >= t1, "Timestamps must be monotonic: \(t1) -> \(t2)")
    }

    /// pv_perf_get_counter must return a positive raw tick value.
    @Test func getCounter_returnsPositive() {
        let c = pv_perf_get_counter()
        #expect(c > 0, "Expected positive perf counter tick, got \(c)")
    }

    /// Two successive counter reads must be monotonically non-decreasing.
    @Test func getCounter_isMonotonic() {
        let c1 = pv_perf_get_counter()
        let c2 = pv_perf_get_counter()
        #expect(c2 >= c1, "Counter ticks must be monotonic: \(c1) -> \(c2)")
    }
}

// MARK: - CPU feature detection tests

struct PerfCPUFeatureTests {

    /// CPU feature detection must report the expected SIMD capabilities for the
    /// current architecture.
    @Test func getCPUFeatures_reportsExpectedSIMD() {
        let features = pv_perf_get_cpu_features()
    #if arch(arm64)
        #expect(features & UInt64(RETRO_SIMD_NEON) != 0, "ARM64 must report RETRO_SIMD_NEON")
        #expect(features & UInt64(RETRO_SIMD_ASIMD) != 0, "ARM64 must report RETRO_SIMD_ASIMD")
    #elseif arch(x86_64)
        #expect(features & UInt64(RETRO_SIMD_SSE) != 0, "x86_64 must report RETRO_SIMD_SSE")
        #expect(features & UInt64(RETRO_SIMD_SSE2) != 0, "x86_64 must report RETRO_SIMD_SSE2")
    #endif
        _ = features
    }
}

// MARK: - Counter lifecycle tests

struct PerfCounterTests {

    /// Registering a fresh counter must set its `registered` flag to true.
    @Test func register_setsRegisteredFlag() {
        let counter = makeCounter("test_register")
        #expect(counter.pointee.registered == false)
        pv_perf_register(counter)
        #expect(counter.pointee.registered == true,
                "Counter must be marked registered after pv_perf_register")
    }

    /// Double-registering the same counter must be a no-op.
    @Test func register_doubleRegister_isNoOp() {
        let counter = makeCounter("test_double_reg")
        pv_perf_register(counter)
        pv_perf_register(counter)
        #expect(counter.pointee.registered == true)
    }

    /// start/stop must increment call_cnt and accumulate a non-zero total.
    @Test func startStop_accumulatesTime() {
        let counter = makeCounter("test_start_stop")
        pv_perf_register(counter)

        #expect(counter.pointee.call_cnt == 0)
        #expect(counter.pointee.total == 0)

        pv_perf_start(counter)
        var dummy: UInt64 = 0
        for i: UInt64 in 0..<1000 {
            dummy &+= i
        }
        _ = dummy
        pv_perf_stop(counter)

        #expect(counter.pointee.call_cnt == 1,
                "call_cnt must be 1 after one start/stop cycle")
        #expect(counter.pointee.total > 0,
                "total must be > 0 after a start/stop cycle with work")
    }

    /// Multiple start/stop cycles must accumulate both call_cnt and total.
    @Test func startStop_multipleRounds_accumulate() {
        let counter = makeCounter("test_multi_round")
        pv_perf_register(counter)

        let rounds: UInt64 = 5
        for _ in 0..<rounds {
            pv_perf_start(counter)
            var dummy: UInt64 = 0
            for i: UInt64 in 0..<100 {
                dummy &+= i
            }
            _ = dummy
            pv_perf_stop(counter)
        }

        #expect(counter.pointee.call_cnt == rounds,
                "call_cnt must equal the number of start/stop rounds")
        #expect(counter.pointee.total > 0,
                "total must be > 0 after multiple rounds")
    }

    /// pv_perf_start with a NULL counter must not crash.
    @Test func start_withNilCounter_doesNotCrash() {
        pv_perf_start(nil)
    }

    /// pv_perf_stop with a NULL counter must not crash.
    @Test func stop_withNilCounter_doesNotCrash() {
        pv_perf_stop(nil)
    }

    /// pv_perf_register with a NULL counter must not crash.
    @Test func register_withNilCounter_doesNotCrash() {
        pv_perf_register(nil)
    }
}

// MARK: - Logging tests

struct PerfLogTests {

    /// pv_perf_log must not crash after a counter has been exercised.
    @Test func perfLog_doesNotCrash() {
        let counter = makeCounter("test_log")
        pv_perf_register(counter)
        pv_perf_start(counter)
        pv_perf_stop(counter)
        pv_perf_log()
    }
}
