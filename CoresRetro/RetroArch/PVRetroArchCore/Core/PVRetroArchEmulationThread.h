//
//  PVRetroArchEmulationThread.h
//  PVRetroArch
//
//  Long-lived NSThread that owns a CFRunLoop dedicated to driving the
//  RetroArch frame loop (runloop_iterate / task_queue_check). Pulling the
//  observer off CFRunLoopGetMain() prevents UI freezes when RA tasks
//  (netplay handshakes, ZIP downloads, core init) take longer than a frame.
//

#ifndef PVRetroArchEmulationThread_h
#define PVRetroArchEmulationThread_h

#include <CoreFoundation/CoreFoundation.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Lazily spawn the emulation thread and block until its CFRunLoop is ready.
/// Idempotent: subsequent calls are no-ops.
void pv_retro_emu_thread_start(void);

/// CFRunLoop owned by the emulation thread. Call `pv_retro_emu_thread_start()`
/// first; returns NULL if the thread has not started yet.
CFRunLoopRef pv_retro_emu_thread_runloop(void);

/// Wake the emulation thread's runloop. Safe to call from any thread.
void pv_retro_emu_thread_wakeup(void);

/// Block the calling thread until any in-flight observer callback on the
/// emulation thread has returned and an idle pass has completed. Use this
/// before tearing down RetroArch state (main_exit etc.) to avoid racing the
/// frame loop. No-op if the emulation thread has not started.
void pv_retro_emu_thread_drain(void);

/// Tear down the emulation thread. Invalidates the keep-alive source so the
/// runloop returns and the thread exits cleanly.
void pv_retro_emu_thread_stop(void);

#ifdef __cplusplus
}
#endif

#endif /* PVRetroArchEmulationThread_h */
