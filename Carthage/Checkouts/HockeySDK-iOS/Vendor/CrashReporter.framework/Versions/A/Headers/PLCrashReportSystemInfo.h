/*
 * Author: Landon Fuller <landonf@plausiblelabs.com>
 *
 * Copyright (c) 2008-2009 Plausible Labs Cooperative, Inc.
 * All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */

#import <Foundation/Foundation.h>

/**
 * @ingroup constants
 *
 * Indicates the Operating System under which a Crash Log was generated.
 *
 * @internal
 * These enum values match the protobuf values. Keep them synchronized.
 */
typedef enum {
    /** Mac OS X. */
    PLCrashReportOperatingSystemMacOSX = 0,
    
    /** iPhone OS */
    PLCrashReportOperatingSystemiPhoneOS = 1,
    
    /** iPhone Simulator (Mac OS X with additional simulator-specific runtime libraries) */
    PLCrashReportOperatingSystemiPhoneSimulator = 2,
    
    /** Unknown operating system */
    PLCrashReportOperatingSystemUnknown = 3,
  
    /** Apple tvOS */
    PLCrashReportOperatingSystemAppleTVOS = 4,
  
} PLCrashReportOperatingSystem;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdocumentation-deprecated-sync"
/**
 * @ingroup constants
 *
 * Indicates the architecture under which a Crash Log was generated.
 *
 * @deprecated The architecture value has been deprecated in v1.1 and later crash reports. All new reports
 * will make use of the new PLCrashReportProcessorInfo CPU type encodings.
 *
 * @internal
 * These enum values match the protobuf values. Keep them synchronized.
 */
typedef enum {
    /** x86-32. */
    PLCrashReportArchitectureX86_32 = 0,
    
    /** x86-64 */
    PLCrashReportArchitectureX86_64 = 1,

    /** ARMv6 */
    PLCrashReportArchitectureARMv6 = 2,

    /**
     * ARMv6
     * @deprecated This value has been deprecated in favor of ARM subtype-specific
     * values.
     * @sa PLCrashReportArchitectureARMv6
     */
    PLCrashReportArchitectureARM = PLCrashReportArchitectureARMv6,

    /** PPC */
    PLCrashReportArchitecturePPC = 3,
    
    /** PPC64 */
    PLCrashReportArchitecturePPC64 = 4,
    
    /** ARMv7 */
    PLCrashReportArchitectureARMv7 = 5,
    
    /** Unknown */
    PLCrashReportArchitectureUnknown = 6
} PLCrashReportArchitecture;
#pragma clang diagnostic pop

extern PLCrashReportOperatingSystem PLCrashReportHostOperatingSystem;
extern PLCrashReportArchitecture PLCrashReportHostArchitecture;

@interface PLCrashReportSystemInfo : NSObject {
@private
    /** Operating system */
    PLCrashReportOperatingSystem _operatingSystem;
    
    /** Operating system version */
    NSString *_osVersion;
    
    /** OS build. May be nil. */
    NSString *_osBuild;
    
    /** Architecture */
    PLCrashReportArchitecture _architecture;
    
    /** Date crash report was generated. May be nil if the date is unknown. */
    NSDate *_timestamp;
}

- (id) initWithOperatingSystem: (PLCrashReportOperatingSystem) operatingSystem 
        operatingSystemVersion: (NSString *) operatingSystemVersion
                  architecture: (PLCrashReportArchitecture) architecture
                     timestamp: (NSDate *) timestamp;

- (id) initWithOperatingSystem: (PLCrashReportOperatingSystem) operatingSystem 
        operatingSystemVersion: (NSString *) operatingSystemVersion
          operatingSystemBuild: (NSString *) operatingSystemBuild
                  architecture: (PLCrashReportArchitecture) architecture
                     timestamp: (NSDate *) timestamp;

/** The operating system. */
@property(nonatomic, readonly) PLCrashReportOperatingSystem operatingSystem;

/** The operating system's release version. */
@property(nonatomic, readonly) NSString *operatingSystemVersion;

/** The operating system's build identifier (eg, 10J869). This may be unavailable, and this property will be nil. */
@property(nonatomic, readonly) NSString *operatingSystemBuild;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdocumentation-deprecated-sync"
/** Architecture. @deprecated The architecture value has been deprecated in v1.1 and later crash reports. All new reports
 * include the CPU type as part of the crash report's machine info structure, using the PLCrashReportProcessorInfo
 * extensible encoding. */
@property(nonatomic, readonly) PLCrashReportArchitecture architecture;
#pragma clang diagnostic pop

/** Date and time that the crash report was generated. This may be unavailable, and this property will be nil. */
@property(nonatomic, readonly) NSDate *timestamp;

@end
