//
//  PVLibRetro+JIT.swift
//  PVCoreBridgeRetro
//
//  Bridges DOLJitManager.acquired (PVJIT/JITManager) into a C-callable
//  function so the ObjC/ObjC++ libretro env-callback handler can query
//  the real runtime JIT state instead of a hardcoded `true`.
//

#if !os(tvOS)
import JITManager
#endif

/// Returns `true` if Provenance has successfully acquired JIT at runtime.
///
/// Thread-safe: `DOLJitManager.acquired` is a `nonisolated(unsafe)` static
/// Bool written once from the main actor at app startup, before any libretro
/// core requests `RETRO_ENVIRONMENT_GET_JIT_CAPABLE`.
///
/// Exposed as a C symbol so the ObjC/ObjC++ env-callback implementations
/// can call it without bridging through a Swift object.
///
/// On tvOS, JIT is never available so this always returns `false`.
@_cdecl("pvjit_acquired")
func pvjitAcquired() -> Bool {
    #if os(tvOS)
    return false
    #else
    return DOLJitManager.acquired
    #endif
}
