//
//  CoreDidThrow+NotificationName.swift
//  PVUIBase
//
//  Typed `Notification.Name` constants for the "core threw a C++
//  exception" notifications posted by the thin libretro wrapper
//  (`PVThinLibretroFrontend.mm`) and the thick RA wrapper trampoline
//  (`PVRetroArchCore+ExceptionTrampoline.mm`).
//
//  Source of truth for the underlying STRING values is the ObjC
//  `NSNotificationName` constants in those modules' headers:
//    - PVCoreBridgeRetro/Sources/PVLibRetro/PVThinLibretroFrontend.h
//        → PVThinLibretroFrontendCoreDidThrowNotification
//    - CoresRetro/RetroArch/PVRetroArchCore/Core/PVRetroArchCore+ExceptionTrampoline.h
//        → PVRetroArchCoreDidThrowNotification
//
//  We define a thin Swift mirror here rather than `import`-ing those
//  modules from PVUIBase to keep the layering clean (PVUIBase doesn't
//  depend on PVCoreBridgeRetro / PVRetroArch). The strings must stay
//  in sync; if you change one, change the other.
//

import Foundation

public extension Notification.Name {
    /// Posted (main) by `PVThinLibretroFrontend.runFrame`'s try/catch
    /// boundary when the dlopened libretro core throws an unhandled
    /// C++ / `NSException` (typically `vk::DeviceLostError` from a
    /// Vulkan-HPP core that hit a GPU budget limit).
    /// `userInfo["reason"]` carries the `what()` / `reason` string.
    static let pvThinLibretroFrontendCoreDidThrow =
        Notification.Name("PVThinLibretroFrontendCoreDidThrow")

    /// Posted (main) by the thick RetroArch wrapper's exception
    /// trampoline when `runloop_iterate()` catches an unhandled core
    /// throw. Same `userInfo["reason"]` payload as the thin variant.
    static let pvRetroArchCoreDidThrow =
        Notification.Name("PVRetroArchCoreDidThrowNotification")
}
