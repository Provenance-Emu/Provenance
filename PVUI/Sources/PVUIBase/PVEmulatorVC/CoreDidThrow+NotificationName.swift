//
//  CoreDidThrow+NotificationName.swift
//  PVUIBase
//
//  Typed `Notification.Name` constant for the "core threw a C++
//  exception" notification posted by the thin libretro wrapper
//  (`PVThinLibretroFrontend.mm`).
//
//  Source of truth for the underlying STRING value is the ObjC
//  `NSNotificationName` constant in the wrapper's header:
//    - PVCoreBridgeRetro/Sources/PVLibRetro/PVThinLibretroFrontend.h
//        → PVThinLibretroFrontendCoreDidThrowNotification
//
//  We define a thin Swift mirror here rather than `import`-ing that
//  module from PVUIBase to keep the layering clean (PVUIBase doesn't
//  depend on PVCoreBridgeRetro). The strings must stay in sync; if you
//  change one, change the other.
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
}
