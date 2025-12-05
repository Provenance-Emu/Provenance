import Foundation

#if canImport(Darwin)
import Darwin
#endif

public enum DebuggerDetector {
    public static var isAttached: Bool {
        #if canImport(Darwin)
        var info = kinfo_proc()
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        var size = MemoryLayout<kinfo_proc>.stride

        let result = mib.withUnsafeMutableBufferPointer { buffer -> Int32 in
            sysctl(buffer.baseAddress, u_int(buffer.count), &info, &size, nil, 0)
        }

        guard result == 0 else {
            return false
        }

        return (info.kp_proc.p_flag & P_TRACED) != 0
        #else
        return false
        #endif
    }
}
