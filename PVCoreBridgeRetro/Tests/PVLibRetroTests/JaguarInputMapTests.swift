//
//  JaguarInputMapTests.swift
//  PVLibRetroTests
//
//  virtualjaguar reads RetroPad A as Jaguar A, B as B, Y as C, SELECT as Pause
//  and START as Option. Skin buttons must land on the same Jaguar button.
//

import Testing
import PVCoreBridge
@testable import PVCoreBridgeRetro

struct JaguarInputMapTests {

    @Test func faceButtonsKeepTheirNames() {
        #expect(PVThinLibretroCore.jaguarMap(.a) == .a)
        #expect(PVThinLibretroCore.jaguarMap(.b) == .b)
        #expect(PVThinLibretroCore.jaguarMap(.c) == .y)
    }

    @Test func pauseIsSelectAndOptionIsStart() {
        #expect(PVThinLibretroCore.jaguarMap(.pause) == .select)
        #expect(PVThinLibretroCore.jaguarMap(.option) == .start)
    }

    @Test func keyboardOnlyKeysPressNoJoypadBit() {
        for button in [PVJaguarButton.button7, .button8, .button9, .asterisk, .pound, .count] {
            #expect(PVThinLibretroCore.jaguarMap(button) == nil)
        }
    }
}
