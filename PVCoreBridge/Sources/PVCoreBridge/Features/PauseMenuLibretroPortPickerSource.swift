//
//  PauseMenuLibretroPortPickerSource.swift
//  PVCoreBridge
//
//  Typed pause-menu port device rows for cores that hide the CORE-tab picker but still expose SET_CONTROLLER_INFO.
//

import Foundation

/// Libretro-backed cores that surface `RETRO_ENVIRONMENT_SET_CONTROLLER_INFO` in the **pause menu** even when
/// they intentionally hide the CORE-tab picker by returning empty ``PortDeviceConfigurable/controllerPortDescriptors``.
///
/// **Example:** ``PVRetroArchCoreCore`` keeps the CORE tab free of duplicate UI (RetroArch has its own input menu)
/// but still exposes per-port device types here so users can switch mouse/lightgun/etc. from Provenance’s pause menu.
public protocol PauseMenuLibretroPortPickerSource: AnyObject {
    /// Per-port device types from `RETRO_ENVIRONMENT_SET_CONTROLLER_INFO` (e.g. RetroArch: ``PVRetroArchCoreBridge/menuControllerPortInfo``), mapped to ``PortDeviceDescriptor``.
    var pauseMenuPortDeviceDescriptors: [[PortDeviceDescriptor]] { get }

    /// Applies a device type for a port; implementations should match ``PortDeviceConfigurable/setDeviceType(_:forPort:)`` semantics.
    func setPauseMenuPortDevice(_ deviceType: UInt, forPort port: Int)
}
