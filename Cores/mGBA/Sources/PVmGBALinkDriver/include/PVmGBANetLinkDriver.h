//
//  PVmGBANetLinkDriver.h
//  PVCoremGBA
//
//  A GBASIODriver that runs mGBA's serial port in lockstep with a GBA on
//  another device, over a PVGBALinkSession.
//
//  Used by the bridge's Objective-C and by PVmGBALinkDriverTests.
//
//  Threading: every function here runs on the emulation thread. The session
//  does its socket I/O on its own thread; this driver only reads the
//  session's inbox.
//

#ifndef PVMGBANETLINKDRIVER_H
#define PVMGBANETLINKDRIVER_H

#include <stdbool.h>

#include "PVmGBALink.h"

#ifdef __cplusplus
extern "C" {
#endif

struct mCore;
struct GBASIODriver;

typedef struct PVmGBANetLinkDriver PVmGBANetLinkDriver;

/// A driver for the session's player. The session must have finished its
/// handshake and must outlive the driver.
PVmGBANetLinkDriver *PVmGBANetLinkDriverCreate(PVGBALinkSession *session);

/// Frees a driver that is no longer installed in a core.
void PVmGBANetLinkDriverFree(PVmGBANetLinkDriver *driver);

/// The GBASIODriver to hand to GBASIOSetDriver.
struct GBASIODriver *PVmGBANetLinkDriverBase(PVmGBANetLinkDriver *driver);

/// Why a driver stopped being linked.
typedef enum PVmGBANetLinkFailure {
    PVmGBANetLinkFailureNone = 0,
    /// The session closed, or a send failed.
    PVmGBANetLinkFailureConnection = 1,
    /// The host queued more events than the client can hold.
    PVmGBANetLinkFailureOverflow = 2,
} PVmGBANetLinkFailure;

/// NO once the link is lost. An unlinked driver behaves like an unplugged
/// cable: no partner, transfers finish with 0xFFFF, nothing ever waits.
bool PVmGBANetLinkDriverIsLinked(const PVmGBANetLinkDriver *driver);

PVmGBANetLinkFailure PVmGBANetLinkDriverFailure(const PVmGBANetLinkDriver *driver);

/// Runs one frame of a GBA core with this driver installed, in place of
/// core->runFrame. While the link makes the emulator wait for the other
/// device, it waits at most `waitBudgetMs` in total, then returns early so
/// the caller can release its locks; the next call carries on mid-frame.
///
/// Returns true if the frame finished. `outStalled` is set when the budget
/// ran out while waiting.
bool PVmGBANetLinkDriverRunFrame(PVmGBANetLinkDriver *driver, struct mCore *core, int waitBudgetMs,
                                 bool *outStalled);

#ifdef __cplusplus
}
#endif

#endif /* PVMGBANETLINKDRIVER_H */
