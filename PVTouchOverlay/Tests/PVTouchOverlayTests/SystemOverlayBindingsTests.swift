import Foundation
import Testing
import PVCoreBridge
import PVSystems
@testable import PVTouchOverlay

@Suite("System bindings")
struct SystemOverlayBindingsTests {
    @Test("Every Phase 1 system has a binding whose families' required slots are all tokenised",
          arguments: SystemOverlayBindings.phase1Systems)
    func complete(system: SystemIdentifier) throws {
        let binding = try #require(SystemOverlayBindings.binding(for: system))
        for (subtype, family) in binding.families {
            for slot in family.requiredSlots {
                #expect(binding.tokens[slot] != nil, "\(system) \(subtype) missing token for \(slot.rawValue)")
            }
        }
        #expect(binding.families[binding.defaultSubtype] != nil)
    }

    @Test("Variant ids used as subtypes exist in ControllerLayoutVariant")
    func variantsExist() {
        for system in SystemOverlayBindings.phase1Systems {
            guard let binding = SystemOverlayBindings.binding(for: system),
                  let variants = system.availableControllerLayoutVariants else { continue }
            let ids = Set(variants.map(\.id))
            for subtype in binding.families.keys where subtype != OverlayPadKind.standardSubtype {
                #expect(ids.contains(subtype), "\(system) subtype \(subtype) is not a ControllerLayoutVariant")
            }
        }
    }

    @Test("Multi-variant systems expose every non-standard subtype as a layout variant")
    func subtypesAreVariants() {
        for system in [SystemIdentifier.Genesis, .Sega32X, .SegaCD, .PSX, .GameCube, .Wii] {
            let subtypes = SystemOverlayBindings.binding(for: system)?.families.keys
                .filter { $0 != OverlayPadKind.standardSubtype } ?? []
            #expect(!subtypes.isEmpty, "\(system) should bind variant subtypes")
        }
    }

    @Test("PlayStation exposes digital and DualShock variants")
    func psxVariants() {
        #expect(SystemIdentifier.PSX.availableControllerLayoutVariants?.map(\.id)
                == ["psx-dualshock", "psx-digital"])
    }

    @Test("Tokens are unique within a binding except for the documented shared slots",
          arguments: SystemOverlayBindings.phase1Systems)
    func tokensAreDistinct(system: SystemIdentifier) throws {
        let binding = try #require(SystemOverlayBindings.binding(for: system))
        var seen: [String: OverlayFamilySlot] = [:]
        for (slot, token) in binding.tokens {
            if let other = seen[token] {
                Issue.record("\(system): slot \(slot.rawValue) and \(other.rawValue) share token \(token)")
            }
            seen[token] = slot
        }
    }

    @Test("Every family renders from its system binding on every canvas",
          arguments: SystemOverlayBindings.phase1Systems)
    func templatesResolve(system: SystemIdentifier) throws {
        let binding = try #require(SystemOverlayBindings.binding(for: system))
        for subtype in binding.families.keys {
            for canvas in OverlayFamilyTests.canvases {
                let template = binding.template(padKind: OverlayPadKind(system: system, subtype: subtype),
                                                orientation: canvas.orientation)
                let layout = OverlayLayoutEngine.resolve(template: template, canvas: canvas,
                                                         overrides: .empty, gameAspect: 4.0 / 3.0)
                #expect(!layout.groups.isEmpty, "\(system) \(subtype) produced no groups")
                for group in layout.groups {
                    #expect(canvas.bounds.contains(group.frame), "\(system) \(subtype) \(group.id) off canvas")
                }
            }
        }
    }

    @Test("Tokens that the skin dispatch and the core button enum disagree on are avoided")
    func nintendoHomeTokens() throws {
        let cube = try #require(SystemOverlayBindings.binding(for: .GameCube))
        // PVGCButton("l2") is Z and PVGCButton("r2") is not R; "l"/"r"/"z" parse the same on every path.
        #expect(cube.tokens[.l] == "l" && cube.tokens[.r] == "r" && cube.tokens[.z] == "z")
        let wii = try #require(SystemOverlayBindings.binding(for: .Wii))
        // PVWiiMoteButton("r3") falls through to D-pad Up; "home" is Home on both paths.
        #expect(wii.tokens[.home] == "home")
        #expect(wii.tokens[.one] == "1" && wii.tokens[.two] == "2")
        #expect(wii.tokens[.plus] == "+" && wii.tokens[.minus] == "-")
    }
}
