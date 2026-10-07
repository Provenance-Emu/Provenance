//
//  ThinLayoutVariantTests.swift
//  PVLibRetroTests
//
//  Controller layout variants map to and from the port devices the cores declare
//  through SET_CONTROLLER_INFO (names as Genesis Plus GX, PCSX-ReARMed and Beetle PSX
//  report them).
//

import Testing
import PVCoreBridge
import PVSystems
@testable import PVCoreBridgeRetro

struct ThinLayoutVariantTests {
    // RETRO_DEVICE_SUBCLASS(base, id) = ((id + 1) << 8) | base
    private static let analogBase: UInt = 5
    private static func subclass(_ base: UInt, _ index: UInt) -> UInt { ((index + 1) << 8) | base }

    private static let genesisPlusGX: [PortDeviceDescriptor] = [
        PortDeviceDescriptor(name: "Joypad Auto", deviceType: 1),
        PortDeviceDescriptor(name: "Joypad Port Empty", deviceType: 0),
        PortDeviceDescriptor(name: "MD Joypad 3 Button + Teamplayer", deviceType: subclass(1, 5)),
        PortDeviceDescriptor(name: "MD Joypad 3 Button", deviceType: subclass(1, 0)),
        PortDeviceDescriptor(name: "MD Joypad 6 Button + 4-WayPlay", deviceType: subclass(1, 4)),
        PortDeviceDescriptor(name: "MD Joypad 6 Button", deviceType: subclass(1, 1))
    ]

    private static let pcsxReARMed: [PortDeviceDescriptor] = [
        PortDeviceDescriptor(name: "standard", deviceType: 1),
        PortDeviceDescriptor(name: "analog", deviceType: subclass(analogBase, 0)),
        PortDeviceDescriptor(name: "dualshock", deviceType: subclass(analogBase, 1)),
        PortDeviceDescriptor(name: "guncon", deviceType: subclass(4, 0))
    ]

    @Test("Genesis variants pick the single pad, never a multitap entry")
    func genesisApply() throws {
        let three = try #require(PVThinLibretroCore.portDevice(for: "genesis-3btn", in: Self.genesisPlusGX))
        #expect(three.name == "MD Joypad 3 Button")
        let six = try #require(PVThinLibretroCore.portDevice(for: "genesis-6btn", in: Self.genesisPlusGX))
        #expect(six.name == "MD Joypad 6 Button")
    }

    @Test("Genesis read-back: Joypad Auto and multitaps are no variant")
    func genesisReadBack() {
        let devices = Self.genesisPlusGX
        #expect(PVThinLibretroCore.variantID(for: devices[3], system: .Genesis) == "genesis-3btn")
        #expect(PVThinLibretroCore.variantID(for: devices[5], system: .SegaCD) == "genesis-6btn")
        #expect(PVThinLibretroCore.variantID(for: devices[0], system: .Genesis) == nil)
        #expect(PVThinLibretroCore.variantID(for: devices[2], system: .Sega32X) == nil)
    }

    @Test("PlayStation variants map to the joypad and the DualShock")
    func psxApply() throws {
        let digital = try #require(PVThinLibretroCore.portDevice(for: "psx-digital", in: Self.pcsxReARMed))
        #expect(digital.name == "standard")
        let dualShock = try #require(PVThinLibretroCore.portDevice(for: "psx-dualshock", in: Self.pcsxReARMed))
        #expect(dualShock.name == "dualshock")
        #expect(PVThinLibretroCore.portDevice(for: "wii-classic", in: Self.pcsxReARMed) == nil)
    }

    @Test("PlayStation read-back: analog pads draw the dual-stick layout, a gun none")
    func psxReadBack() {
        let devices = Self.pcsxReARMed
        #expect(PVThinLibretroCore.variantID(for: devices[0], system: .PSX) == "psx-digital")
        #expect(PVThinLibretroCore.variantID(for: devices[1], system: .PSX) == "psx-dualshock")
        #expect(PVThinLibretroCore.variantID(for: devices[2], system: .PSX) == "psx-dualshock")
        #expect(PVThinLibretroCore.variantID(for: devices[3], system: .PSX) == nil)
        let beetle = PortDeviceDescriptor(name: "DualAnalog", deviceType: Self.subclass(Self.analogBase, 0))
        #expect(PVThinLibretroCore.variantID(for: beetle, system: .PSX) == "psx-dualshock")
    }

    @Test("Only a chosen device reads back: the untouched default joypad is no variant")
    func storedDeviceOnly() {
        let devices = Self.pcsxReARMed
        #expect(PVThinLibretroCore.variantID(currentDevice: 1, hasStoredDevice: false,
                                             in: devices, system: .PSX) == nil)
        #expect(PVThinLibretroCore.variantID(currentDevice: 1, hasStoredDevice: true,
                                             in: devices, system: .PSX) == "psx-digital")
        #expect(PVThinLibretroCore.variantID(currentDevice: Self.subclass(Self.analogBase, 1), hasStoredDevice: true,
                                             in: devices, system: .PSX) == "psx-dualshock")
        #expect(PVThinLibretroCore.variantID(currentDevice: 99, hasStoredDevice: true,
                                             in: devices, system: .PSX) == nil)
    }

    @Test("Systems without variants report none")
    func otherSystems() {
        #expect(PVThinLibretroCore.variantID(for: Self.pcsxReARMed[0], system: .SNES) == nil)
    }
}
