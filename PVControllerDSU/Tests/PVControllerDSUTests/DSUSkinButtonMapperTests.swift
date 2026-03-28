import Testing
@testable import PVControllerDSU

// MARK: - DSUSkinButtonMapper tests

@Suite("DSUSkinButtonMapper")
struct DSUSkinButtonMapperTests {

    // MARK: - D-pad

    @Test("dpad_up sets buttons1 bit and analog value on press")
    func dpadUp() {
        var data = DSUControllerData()
        DSUSkinButtonMapper.apply(inputID: "up", pressed: true, to: &data)
        #expect(data.buttons1 & 0x08 != 0)
        #expect(data.dpadUp == 255)

        DSUSkinButtonMapper.apply(inputID: "up", pressed: false, to: &data)
        #expect(data.buttons1 & 0x08 == 0)
        #expect(data.dpadUp == 0)
    }

    @Test("dpad IDs with underscore prefix are recognised")
    func dpadPrefixVariants() {
        var data = DSUControllerData()
        // "dpad_left" and "left" should produce the same effect
        DSUSkinButtonMapper.apply(inputID: "dpad_left", pressed: true, to: &data)
        #expect(data.buttons1 & 0x02 != 0)
        #expect(data.dpadLeft == 255)
    }

    @Test("all four dpad directions set distinct bits")
    func dpadAllDirections() {
        var data = DSUControllerData()
        DSUSkinButtonMapper.apply(inputID: "up",    pressed: true, to: &data)
        DSUSkinButtonMapper.apply(inputID: "down",  pressed: true, to: &data)
        DSUSkinButtonMapper.apply(inputID: "left",  pressed: true, to: &data)
        DSUSkinButtonMapper.apply(inputID: "right", pressed: true, to: &data)
        // Bits 0-3 in buttons1 should all be set
        #expect(data.buttons1 & 0x0F == 0x0F)
    }

    // MARK: - Face buttons

    @Test("Nintendo 'a' maps to DSU cross")
    func buttonA() {
        var data = DSUControllerData()
        DSUSkinButtonMapper.apply(inputID: "a", pressed: true, to: &data)
        #expect(data.buttons2 & 0x08 != 0)  // cross bit
        #expect(data.buttonCross == 255)
    }

    @Test("'cross' alias produces same result as 'a'")
    func crossAlias() {
        var dataA = DSUControllerData()
        var dataCross = DSUControllerData()
        DSUSkinButtonMapper.apply(inputID: "a",     pressed: true, to: &dataA)
        DSUSkinButtonMapper.apply(inputID: "cross",  pressed: true, to: &dataCross)
        #expect(dataA.buttons2 == dataCross.buttons2)
        #expect(dataA.buttonCross == dataCross.buttonCross)
    }

    @Test("all face buttons set distinct bits in buttons2")
    func faceButtonBits() {
        var data = DSUControllerData()
        DSUSkinButtonMapper.apply(inputID: "a", pressed: true, to: &data) // cross bit  8
        DSUSkinButtonMapper.apply(inputID: "b", pressed: true, to: &data) // circle bit 4
        DSUSkinButtonMapper.apply(inputID: "x", pressed: true, to: &data) // square bit 2
        DSUSkinButtonMapper.apply(inputID: "y", pressed: true, to: &data) // triangle bit 1
        #expect(data.buttons2 & 0x0F == 0x0F)
    }

    // MARK: - Shoulder / trigger buttons

    @Test("L1 sets bit and analog")
    func l1Button() {
        var data = DSUControllerData()
        DSUSkinButtonMapper.apply(inputID: "l1", pressed: true, to: &data)
        #expect(data.buttons2 & 0x80 != 0)
        #expect(data.buttonL1 == 255)
    }

    @Test("L2 sets bit, analog, and trigger byte")
    func l2Trigger() {
        var data = DSUControllerData()
        DSUSkinButtonMapper.apply(inputID: "l2", pressed: true, to: &data)
        #expect(data.buttons2 & 0x20 != 0)
        #expect(data.buttonL2 == 255)
        #expect(data.triggerL2 == 255)
    }

    @Test("ZL alias maps to L2")
    func zlAliasL2() {
        var dataL2 = DSUControllerData()
        var dataZL = DSUControllerData()
        DSUSkinButtonMapper.apply(inputID: "l2", pressed: true, to: &dataL2)
        DSUSkinButtonMapper.apply(inputID: "zl", pressed: true, to: &dataZL)
        #expect(dataL2.buttons2 == dataZL.buttons2)
        #expect(dataL2.triggerL2 == dataZL.triggerL2)
    }

    @Test("R2 / RT / ZR all set trigger byte")
    func r2Aliases() {
        let ids = ["r2", "rt", "zr"]
        for id in ids {
            var data = DSUControllerData()
            DSUSkinButtonMapper.apply(inputID: id, pressed: true, to: &data)
            #expect(data.triggerR2 == 255, "'\(id)' should set triggerR2")
        }
    }

    // MARK: - Meta buttons

    @Test("start / options / plus all set the same bit")
    func startAliases() {
        let ids = ["start", "options", "plus"]
        for id in ids {
            var data = DSUControllerData()
            DSUSkinButtonMapper.apply(inputID: id, pressed: true, to: &data)
            #expect(data.buttons1 & 0x10 != 0, "'\(id)' should set options bit")
        }
    }

    @Test("select / share / minus / back all set the same bit")
    func selectAliases() {
        let ids = ["select", "share", "minus", "back"]
        for id in ids {
            var data = DSUControllerData()
            DSUSkinButtonMapper.apply(inputID: id, pressed: true, to: &data)
            #expect(data.buttons1 & 0x80 != 0, "'\(id)' should set share bit")
        }
    }

    @Test("ps / home / guide set the PS byte")
    func psButton() {
        let ids = ["ps", "home", "guide"]
        for id in ids {
            var data = DSUControllerData()
            DSUSkinButtonMapper.apply(inputID: id, pressed: true, to: &data)
            #expect(data.psButton == 1, "'\(id)' should set psButton")
        }
    }

    // MARK: - Analog sticks

    @Test("left stick X/Y write correct byte values")
    func leftStick() {
        var data = DSUControllerData()
        DSUSkinButtonMapper.applyAnalogStick(inputID: "leftthumbstick", x: 1.0, y: 0.0, to: &data)
        #expect(data.leftStickX == 255)
        // y=0 in skin space → inverted → byteY = 127
        #expect(data.leftStickY == 127)
    }

    @Test("right stick recognised by alias")
    func rightStickAlias() {
        var data = DSUControllerData()
        DSUSkinButtonMapper.applyAnalogStick(inputID: "rightstick", x: 0.0, y: -1.0, to: &data)
        // x=0 → 127, y=-1 skin → inverted to +1 → byteY=255
        #expect(data.rightStickX == 127)
        #expect(data.rightStickY == 255)
    }

    @Test("stick at neutral (0,0) writes centre byte")
    func stickNeutral() {
        var data = DSUControllerData()
        DSUSkinButtonMapper.applyAnalogStick(inputID: "leftthumbstick", x: 0, y: 0, to: &data)
        // (0 + 1) * 127.5 = 127 (UInt8 truncation)
        #expect(data.leftStickX == 127)
        #expect(data.leftStickY == 127)
    }

    // MARK: - Unknown ID

    @Test("unknown input ID is silently ignored")
    func unknownID() {
        var data = DSUControllerData()
        let before = data
        DSUSkinButtonMapper.apply(inputID: "totally_unknown_button_xyz", pressed: true, to: &data)
        #expect(data == before)
    }

    // MARK: - Case / punctuation normalisation

    @Test("IDs are normalised (case-insensitive, strip underscores)")
    func normalisation() {
        var lower = DSUControllerData()
        var upper = DSUControllerData()
        var underscored = DSUControllerData()
        DSUSkinButtonMapper.apply(inputID: "dpadup",    pressed: true, to: &lower)
        DSUSkinButtonMapper.apply(inputID: "DPadUp",    pressed: true, to: &upper)
        DSUSkinButtonMapper.apply(inputID: "dpad_up",   pressed: true, to: &underscored)
        #expect(lower.buttons1 == upper.buttons1)
        #expect(lower.buttons1 == underscored.buttons1)
    }
}
