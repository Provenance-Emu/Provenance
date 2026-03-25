//
//  PVSettingsTests.swift
//  PVSettings
//
//  Created by Joseph Mattiello on 8/6/24.
//

import Testing
@testable import PVSettings
import Foundation

// MARK: - Defaults Keys Tests

@Suite("Defaults Keys")
struct DefaultsKeysTests {

    @Test("askToAutoLoad default is true")
    func askToAutoLoadDefault() {
        // Reset to default first
        Defaults.reset(.askToAutoLoad)
        #expect(Defaults[.askToAutoLoad] == true)
    }

    @Test("imageSmoothing default is false")
    func imageSmoothingDefault() {
        Defaults.reset(.imageSmoothing)
        #expect(Defaults[.imageSmoothing] == false)
    }

    @Test("vsyncEnabled default is true")
    func vsyncEnabledDefault() {
        Defaults.reset(.vsyncEnabled)
        #expect(Defaults[.vsyncEnabled] == true)
    }

    @Test("volume default is 1.0")
    func volumeDefault() {
        Defaults.reset(.volume)
        #expect(Defaults[.volume] == 1.0)
    }

    @Test("timedAutoSaveInterval default is 10 minutes")
    func timedAutoSaveIntervalDefault() {
        Defaults.reset(.timedAutoSaveInterval)
        #expect(Defaults[.timedAutoSaveInterval] == minutes(10))
    }

    @Test("Boolean setting can be toggled")
    func booleanSettingToggle() {
        Defaults[.imageSmoothing] = false
        #expect(Defaults[.imageSmoothing] == false)
        Defaults[.imageSmoothing].toggle()
        #expect(Defaults[.imageSmoothing] == true)
        Defaults.reset(.imageSmoothing)
    }

    @Test("Setting persists to UserDefaults")
    func settingPersistsToUserDefaults() {
        Defaults[.showFPSCount] = true
        let raw = UserDefaults.standard.bool(forKey: "showFPSCount")
        #expect(raw == true)
        Defaults.reset(.showFPSCount)
    }
}

// MARK: - Recording & Streaming Defaults Tests

@Suite("Recording & Streaming Defaults")
struct RecordingDefaultsTests {

    @Test("recordingMicEnabled default is false")
    func recordingMicEnabledDefault() {
        Defaults.reset(.recordingMicEnabled)
        #expect(Defaults[.recordingMicEnabled] == false)
    }

    @Test("recordingCameraEnabled default is false")
    func recordingCameraEnabledDefault() {
        Defaults.reset(.recordingCameraEnabled)
        #expect(Defaults[.recordingCameraEnabled] == false)
    }

    @Test("recordingAutoSave default is true")
    func recordingAutoSaveDefault() {
        Defaults.reset(.recordingAutoSave)
        #expect(Defaults[.recordingAutoSave] == true)
    }

    @Test("showRecordingOSD default is true")
    func showRecordingOSDDefault() {
        Defaults.reset(.showRecordingOSD)
        #expect(Defaults[.showRecordingOSD] == true)
    }

    @Test("recordingClipDuration default is 30")
    func recordingClipDurationDefault() {
        Defaults.reset(.recordingClipDuration)
        #expect(Defaults[.recordingClipDuration] == 30)
    }

    @Test("recordingMicEnabled key name is correct")
    func recordingMicEnabledKeyName() {
        #expect(Defaults.Keys.recordingMicEnabled.name == "recordingMicEnabled")
    }

    @Test("recordingClipDuration can be changed")
    func recordingClipDurationMutable() {
        Defaults.reset(.recordingClipDuration)
        defer { Defaults.reset(.recordingClipDuration) }
        Defaults[.recordingClipDuration] = 60
        #expect(Defaults[.recordingClipDuration] == 60)
    }

    @Test("recordingCameraPosition default is bottomRight")
    func recordingCameraPositionDefault() {
        Defaults.reset(.recordingCameraPosition)
        #expect(Defaults[.recordingCameraPosition] == .bottomRight)
    }

    @Test("recordingCameraPosition key name is correct")
    func recordingCameraPositionKeyName() {
        #expect(Defaults.Keys.recordingCameraPosition.name == "recordingCameraPosition")
    }

    @Test("recordingCameraPosition can be changed and reset")
    func recordingCameraPositionMutable() {
        Defaults.reset(.recordingCameraPosition)
        defer { Defaults.reset(.recordingCameraPosition) }
        Defaults[.recordingCameraPosition] = .topLeft
        #expect(Defaults[.recordingCameraPosition] == .topLeft)
    }

    @Test("cameraOverlaySize default is medium")
    func cameraOverlaySizeDefault() {
        Defaults.reset(.cameraOverlaySize)
        #expect(Defaults[.cameraOverlaySize] == .medium)
    }

    @Test("cameraOverlaySize key name is correct")
    func cameraOverlaySizeKeyName() {
        #expect(Defaults.Keys.cameraOverlaySize.name == "cameraOverlaySize")
    }

    @Test("cameraOverlaySize can be changed and reset")
    func cameraOverlaySizeMutable() {
        Defaults.reset(.cameraOverlaySize)
        defer { Defaults.reset(.cameraOverlaySize) }
        Defaults[.cameraOverlaySize] = .large
        #expect(Defaults[.cameraOverlaySize] == .large)
    }

    @Test("cameraOverlayShape default is circle")
    func cameraOverlayShapeDefault() {
        Defaults.reset(.cameraOverlayShape)
        #expect(Defaults[.cameraOverlayShape] == .circle)
    }

    @Test("cameraOverlayShape key name is correct")
    func cameraOverlayShapeKeyName() {
        #expect(Defaults.Keys.cameraOverlayShape.name == "cameraOverlayShape")
    }

    @Test("cameraOverlayShape can be changed and reset")
    func cameraOverlayShapeMutable() {
        Defaults.reset(.cameraOverlayShape)
        defer { Defaults.reset(.cameraOverlayShape) }
        Defaults[.cameraOverlayShape] = .roundedRect
        #expect(Defaults[.cameraOverlayShape] == .roundedRect)
    }
}

// MARK: - CameraPosition Tests

@Suite("CameraPosition")
struct CameraPositionTests {

    @Test("All cases present")
    func allCasesCount() {
        #expect(CameraPosition.allCases.count == 4)
    }

    @Test("RawValues are correct")
    func rawValues() {
        #expect(CameraPosition.topLeft.rawValue == "topLeft")
        #expect(CameraPosition.topRight.rawValue == "topRight")
        #expect(CameraPosition.bottomLeft.rawValue == "bottomLeft")
        #expect(CameraPosition.bottomRight.rawValue == "bottomRight")
    }

    @Test("RawValue round-trip")
    func rawValueRoundTrip() {
        for position in CameraPosition.allCases {
            let reconstructed = CameraPosition(rawValue: position.rawValue)
            #expect(reconstructed == position)
        }
    }

    @Test("DisplayNames are non-empty")
    func displayNamesNonEmpty() {
        for position in CameraPosition.allCases {
            #expect(!position.displayName.isEmpty)
        }
    }

    @Test("DisplayNames are correct")
    func displayNames() {
        #expect(CameraPosition.topLeft.displayName == "Top Left")
        #expect(CameraPosition.topRight.displayName == "Top Right")
        #expect(CameraPosition.bottomLeft.displayName == "Bottom Left")
        #expect(CameraPosition.bottomRight.displayName == "Bottom Right")
    }

    @Test("SymbolNames are non-empty")
    func symbolNamesNonEmpty() {
        for position in CameraPosition.allCases {
            #expect(!position.symbolName.isEmpty)
        }
    }
}

// MARK: - CameraOverlaySize Tests

@Suite("CameraOverlaySize")
struct CameraOverlaySizeTests {

    @Test("All cases present")
    func allCasesCount() {
        #expect(CameraOverlaySize.allCases.count == 3)
    }

    @Test("RawValues are correct")
    func rawValues() {
        #expect(CameraOverlaySize.small.rawValue == "small")
        #expect(CameraOverlaySize.medium.rawValue == "medium")
        #expect(CameraOverlaySize.large.rawValue == "large")
    }

    @Test("RawValue round-trip")
    func rawValueRoundTrip() {
        for size in CameraOverlaySize.allCases {
            let reconstructed = CameraOverlaySize(rawValue: size.rawValue)
            #expect(reconstructed == size)
        }
    }

    @Test("Points match expected values")
    func pointValues() {
        #expect(CameraOverlaySize.small.points == 80)
        #expect(CameraOverlaySize.medium.points == 120)
        #expect(CameraOverlaySize.large.points == 160)
    }

    @Test("Points values are ordered small < medium < large")
    func pointsOrdered() {
        #expect(CameraOverlaySize.small.points < CameraOverlaySize.medium.points)
        #expect(CameraOverlaySize.medium.points < CameraOverlaySize.large.points)
    }

    @Test("DisplayNames are non-empty")
    func displayNamesNonEmpty() {
        for size in CameraOverlaySize.allCases {
            #expect(!size.displayName.isEmpty)
        }
    }
}

// MARK: - CameraOverlayShape Tests

@Suite("CameraOverlayShape")
struct CameraOverlayShapeTests {

    @Test("All cases present")
    func allCasesCount() {
        #expect(CameraOverlayShape.allCases.count == 2)
    }

    @Test("RawValues are correct")
    func rawValues() {
        #expect(CameraOverlayShape.circle.rawValue == "circle")
        #expect(CameraOverlayShape.roundedRect.rawValue == "roundedRect")
    }

    @Test("RawValue round-trip")
    func rawValueRoundTrip() {
        for shape in CameraOverlayShape.allCases {
            let reconstructed = CameraOverlayShape(rawValue: shape.rawValue)
            #expect(reconstructed == shape)
        }
    }

    @Test("DisplayNames are non-empty")
    func displayNamesNonEmpty() {
        for shape in CameraOverlayShape.allCases {
            #expect(!shape.displayName.isEmpty)
        }
    }
}

// MARK: - ButtonPressEffect Tests

@Suite("ButtonPressEffect")
struct ButtonPressEffectTests {

    @Test("All cases present")
    func allCasesCount() {
        #expect(ButtonPressEffect.allCases.count == 3)
    }

    @Test("RawValues are correct")
    func rawValues() {
        #expect(ButtonPressEffect.bubble.rawValue == "bubble")
        #expect(ButtonPressEffect.ring.rawValue == "ring")
        #expect(ButtonPressEffect.glow.rawValue == "glow")
    }

    @Test("RawValue round-trip")
    func rawValueRoundTrip() {
        for effect in ButtonPressEffect.allCases {
            let reconstructed = ButtonPressEffect(rawValue: effect.rawValue)
            #expect(reconstructed == effect)
        }
    }

    @Test("Descriptions are non-empty")
    func descriptionsNonEmpty() {
        for effect in ButtonPressEffect.allCases {
            #expect(!effect.description.isEmpty)
        }
    }

    @Test("Descriptions are correct")
    func descriptions() {
        #expect(ButtonPressEffect.bubble.description == "Bubble + Ring")
        #expect(ButtonPressEffect.ring.description == "Ring Only")
        #expect(ButtonPressEffect.glow.description == "Radial Glow")
    }

    @Test("Subtitles are non-empty")
    func subtitlesNonEmpty() {
        for effect in ButtonPressEffect.allCases {
            #expect(!effect.subtitle.isEmpty)
        }
    }

    @Test("Equality works correctly")
    func equality() {
        #expect(ButtonPressEffect.bubble == .bubble)
        #expect(ButtonPressEffect.bubble != .ring)
    }
}

// MARK: - ButtonSound Tests

@Suite("ButtonSound")
struct ButtonSoundTests {

    @Test("All cases present")
    func allCasesCount() {
        #expect(ButtonSound.allCases.count == 9)
    }

    @Test("RawValue round-trip")
    func rawValueRoundTrip() {
        for sound in ButtonSound.allCases {
            let reconstructed = ButtonSound(rawValue: sound.rawValue)
            #expect(reconstructed == sound)
        }
    }

    @Test("Descriptions are non-empty")
    func descriptionsNonEmpty() {
        for sound in ButtonSound.allCases {
            #expect(!sound.description.isEmpty)
        }
    }

    @Test("Filenames for none and generated are empty")
    func emptyFilenames() {
        #expect(ButtonSound.none.filename.isEmpty)
        #expect(ButtonSound.generated.filename.isEmpty)
    }

    @Test("Filenames for sound effects are non-empty")
    func nonEmptyFilenames() {
        let soundsWithFiles: [ButtonSound] = [.click, .tap, .pop, .click2, .tap2, .click3, .switch]
        for sound in soundsWithFiles {
            #expect(!sound.filename.isEmpty, "Expected non-empty filename for \(sound)")
        }
    }

    @Test("Filename values are correct")
    func filenameValues() {
        #expect(ButtonSound.click.filename == "button-click")
        #expect(ButtonSound.tap.filename == "button-tap")
        #expect(ButtonSound.pop.filename == "button-pop")
        #expect(ButtonSound.click2.filename == "button-click2")
        #expect(ButtonSound.click3.filename == "button-click3")
        #expect(ButtonSound.tap2.filename == "button-tap2")
        #expect(ButtonSound.switch.filename == "button-switch")
    }

    @Test("HasReleaseSample is true for click, pop, switch")
    func hasReleaseSampleTrue() {
        #expect(ButtonSound.click.hasReleaseSample)
        #expect(ButtonSound.pop.hasReleaseSample)
        #expect(ButtonSound.switch.hasReleaseSample)
    }

    @Test("HasReleaseSample is false for none, generated, tap, click2, tap2, click3")
    func hasReleaseSampleFalse() {
        let falseOnes: [ButtonSound] = [.none, .generated, .tap, .click2, .tap2, .click3]
        for sound in falseOnes {
            #expect(!sound.hasReleaseSample, "Expected hasReleaseSample == false for \(sound)")
        }
    }
}

// MARK: - CloudKitSyncNetworkMode Tests

@Suite("CloudKitSyncNetworkMode")
struct CloudKitSyncNetworkModeTests {

    @Test("All cases present")
    func allCasesCount() {
        #expect(CloudKitSyncNetworkMode.allCases.count == 3)
    }

    @Test("RawValue round-trip")
    func rawValueRoundTrip() {
        for mode in CloudKitSyncNetworkMode.allCases {
            let reconstructed = CloudKitSyncNetworkMode(rawValue: mode.rawValue)
            #expect(reconstructed == mode)
        }
    }

    @Test("Descriptions are correct")
    func descriptions() {
        #expect(CloudKitSyncNetworkMode.wifiAndCellular.description == "Wi-Fi & Cellular")
        #expect(CloudKitSyncNetworkMode.wifiOnly.description == "Wi-Fi Only")
        #expect(CloudKitSyncNetworkMode.cellularOnly.description == "Cellular Only")
    }

    @Test("Subtitles are non-empty")
    func subtitlesNonEmpty() {
        for mode in CloudKitSyncNetworkMode.allCases {
            #expect(!mode.subtitle.isEmpty)
        }
    }
}

// MARK: - CloudKitSyncFrequency Tests

@Suite("CloudKitSyncFrequency")
struct CloudKitSyncFrequencyTests {

    @Test("All cases present")
    func allCasesCount() {
        #expect(CloudKitSyncFrequency.allCases.count == 5)
    }

    @Test("Immediate timeInterval is nil")
    func immediateTimeIntervalIsNil() {
        #expect(CloudKitSyncFrequency.immediate.timeInterval == nil)
    }

    @Test("Manual timeInterval is nil")
    func manualTimeIntervalIsNil() {
        #expect(CloudKitSyncFrequency.manual.timeInterval == nil)
    }

    @Test("FiveMinutes timeInterval is 300")
    func fiveMinutesTimeInterval() {
        #expect(CloudKitSyncFrequency.fiveMinutes.timeInterval == 300)
    }

    @Test("FifteenMinutes timeInterval is 900")
    func fifteenMinutesTimeInterval() {
        #expect(CloudKitSyncFrequency.fifteenMinutes.timeInterval == 900)
    }

    @Test("Hourly timeInterval is 3600")
    func hourlyTimeInterval() {
        #expect(CloudKitSyncFrequency.hourly.timeInterval == 3600)
    }

    @Test("Descriptions are correct")
    func descriptions() {
        #expect(CloudKitSyncFrequency.immediate.description == "Immediate")
        #expect(CloudKitSyncFrequency.fiveMinutes.description == "Every 5 Minutes")
        #expect(CloudKitSyncFrequency.fifteenMinutes.description == "Every 15 Minutes")
        #expect(CloudKitSyncFrequency.hourly.description == "Hourly")
        #expect(CloudKitSyncFrequency.manual.description == "Manual Only")
    }

    @Test("RawValue round-trip")
    func rawValueRoundTrip() {
        for freq in CloudKitSyncFrequency.allCases {
            let reconstructed = CloudKitSyncFrequency(rawValue: freq.rawValue)
            #expect(reconstructed == freq)
        }
    }
}

// MARK: - CloudKitSyncContentType Tests

@Suite("CloudKitSyncContentType")
struct CloudKitSyncContentTypeTests {

    @Test("All cases present")
    func allCasesCount() {
        #expect(CloudKitSyncContentType.allCases.count == 4)
    }

    @Test("Descriptions are correct")
    func descriptions() {
        #expect(CloudKitSyncContentType.all.description == "Everything")
        #expect(CloudKitSyncContentType.saveStatesOnly.description == "Save States Only")
        #expect(CloudKitSyncContentType.romsOnly.description == "ROMs Only")
        #expect(CloudKitSyncContentType.metadataOnly.description == "Metadata Only")
    }

    @Test("RawValue round-trip")
    func rawValueRoundTrip() {
        for type_ in CloudKitSyncContentType.allCases {
            let reconstructed = CloudKitSyncContentType(rawValue: type_.rawValue)
            #expect(reconstructed == type_)
        }
    }

    @Test("Subtitles are non-empty")
    func subtitlesNonEmpty() {
        for type_ in CloudKitSyncContentType.allCases {
            #expect(!type_.subtitle.isEmpty)
        }
    }
}

// MARK: - MetalFilterModeOption Tests

@Suite("MetalFilterModeOption")
struct MetalFilterModeOptionTests {

    @Test("None rawValue is 'None'")
    func noneRawValue() {
        #expect(MetalFilterModeOption.none.rawValue == "None")
    }

    @Test("Auto rawValue has correct format")
    func autoRawValueFormat() {
        let option = MetalFilterModeOption.auto(crt: .simpleCRT, lcd: .lcd)
        #expect(option.rawValue.hasPrefix("Auto("))
        #expect(option.rawValue.contains("simpleCRT"))
        #expect(option.rawValue.contains("lcd"))
    }

    @Test("Always rawValue has correct format")
    func alwaysRawValueFormat() {
        let option = MetalFilterModeOption.always(filter: .complexCRT)
        #expect(option.rawValue.hasPrefix("Always("))
        #expect(option.rawValue.contains("complexCRT"))
    }

    @Test("None parses from rawValue")
    func noneParseFromRawValue() {
        let parsed = MetalFilterModeOption(rawValue: "None")
        #expect(parsed == .none)
    }

    @Test("Auto parses from rawValue")
    func autoParseFromRawValue() {
        let rawValue = "Auto(simpleCRT, lcd)"
        let parsed = MetalFilterModeOption(rawValue: rawValue)
        #expect(parsed != nil)
        if case .auto(let crt, let lcd) = parsed! {
            #expect(crt == .simpleCRT)
            #expect(lcd == .lcd)
        } else {
            Issue.record("Expected .auto case")
        }
    }

    @Test("Always parses from rawValue")
    func alwaysParseFromRawValue() {
        let rawValue = "Always(complexCRT)"
        let parsed = MetalFilterModeOption(rawValue: rawValue)
        #expect(parsed != nil)
        if case .always(let filter) = parsed! {
            #expect(filter == .complexCRT)
        } else {
            Issue.record("Expected .always case")
        }
    }

    @Test("Invalid rawValue returns nil")
    func invalidRawValueReturnsNil() {
        #expect(MetalFilterModeOption(rawValue: "invalid") == nil)
        #expect(MetalFilterModeOption(rawValue: "") == nil)
        #expect(MetalFilterModeOption(rawValue: "Auto()") == nil)
    }

    @Test("RawValue round-trip for all allCases")
    func rawValueRoundTrip() {
        for option in MetalFilterModeOption.allCases {
            let rawValue = option.rawValue
            let parsed = MetalFilterModeOption(rawValue: rawValue)
            #expect(parsed != nil, "Expected non-nil parse for \(rawValue)")
            #expect(parsed?.rawValue == rawValue)
        }
    }

    @Test("Description equals rawValue")
    func descriptionEqualsRawValue() {
        for option in MetalFilterModeOption.allCases {
            #expect(option.description == option.rawValue)
        }
    }

    @Test("Equality based on rawValue")
    func equalityBasedOnRawValue() {
        #expect(MetalFilterModeOption.none == .none)
        #expect(MetalFilterModeOption.none != .always(filter: .simpleCRT))
        let a1 = MetalFilterModeOption.auto(crt: .simpleCRT, lcd: .lcd)
        let a2 = MetalFilterModeOption.auto(crt: .simpleCRT, lcd: .lcd)
        #expect(a1 == a2)
    }
}

// MARK: - MetalFilterSelectionOption Tests

@Suite("MetalFilterSelectionOption")
struct MetalFilterSelectionOptionTests {

    @Test("All cases present")
    func allCasesCount() {
        // none, simpleCRT, complexCRT, lcd, megaTron, ulTron, gameBoy, vhs
        #expect(MetalFilterSelectionOption.allCases.count == 8)
    }

    @Test("RawValue round-trip")
    func rawValueRoundTrip() {
        for option in MetalFilterSelectionOption.allCases {
            let reconstructed = MetalFilterSelectionOption(rawValue: option.rawValue)
            #expect(reconstructed == option)
        }
    }

    @Test("LCD screenType is .lcd")
    func lcdScreenType() {
        #expect(MetalFilterSelectionOption.lcd.screenType == .lcd)
    }

    @Test("Non-LCD screenTypes are .crt")
    func crtScreenTypes() {
        let crtOptions: [MetalFilterSelectionOption] = [
            .none, .simpleCRT, .complexCRT, .megaTron, .ulTron, .gameBoy, .vhs
        ]
        for option in crtOptions {
            #expect(option.screenType == .crt, "Expected .crt screenType for \(option)")
        }
    }

    @available(*, deprecated, message: "Tests deprecated MetalFilterSelectionOption.hasCRTParameters")
    @Test("hasCRTParameters is true only for simpleCRT and complexCRT")
    func hasCRTParameters() {
        #expect(MetalFilterSelectionOption.simpleCRT.hasCRTParameters)
        #expect(MetalFilterSelectionOption.complexCRT.hasCRTParameters)

        let others: [MetalFilterSelectionOption] = [.none, .lcd, .megaTron, .ulTron, .gameBoy, .vhs]
        for option in others {
            #expect(!option.hasCRTParameters, "Expected hasCRTParameters == false for \(option)")
        }
    }

    @Test("hasEditableParameters is false only for none")
    func hasEditableParameters() {
        #expect(!MetalFilterSelectionOption.none.hasEditableParameters)

        let editableOptions: [MetalFilterSelectionOption] = [.simpleCRT, .complexCRT, .lcd, .megaTron, .ulTron, .gameBoy, .vhs]
        for option in editableOptions {
            #expect(option.hasEditableParameters, "Expected hasEditableParameters == true for \(option)")
        }
    }

    @Test("Descriptions are non-empty")
    func descriptionsNonEmpty() {
        for option in MetalFilterSelectionOption.allCases {
            #expect(!option.description.isEmpty)
        }
    }

    @Test("Descriptions are correct")
    func descriptions() {
        #expect(MetalFilterSelectionOption.none.description == "None")
        #expect(MetalFilterSelectionOption.simpleCRT.description == "Simple CRT")
        #expect(MetalFilterSelectionOption.complexCRT.description == "Complex CRT")
        #expect(MetalFilterSelectionOption.lcd.description == "LCD")
        #expect(MetalFilterSelectionOption.gameBoy.description == "Game Boy")
    }

    @Test("Default value is none")
    func defaultValue() {
        #expect(MetalFilterSelectionOption.defaultValue == .none)
    }
}

// MARK: - OpenGLFilterModeOption Tests

@Suite("OpenGLFilterModeOption")
struct OpenGLFilterModeOptionTests {

    @Test("All cases present")
    func allCasesCount() {
        #expect(OpenGLFilterModeOption.allCases.count == 2)
    }

    @Test("Default value is none")
    func defaultValue() {
        #expect(OpenGLFilterModeOption.defaultValue == .none)
    }

    @Test("Description equals capitalized rawValue")
    func description() {
        #expect(OpenGLFilterModeOption.none.description == "None")
        #expect(OpenGLFilterModeOption.CRT.description == "Crt")
    }

    @Test("Equality works")
    func equality() {
        #expect(OpenGLFilterModeOption.none == .none)
        #expect(OpenGLFilterModeOption.none != .CRT)
    }
}

// MARK: - ThemeOption Tests

@Suite("ThemeOption")
struct ThemeOptionTests {

    @Test("allCases includes standard and CGA themes")
    func allCasesCount() {
        let cases = ThemeOption.allCases
        let standardCount = ThemeOptionsStandard.allCases.count
        let cgaCount = ThemeOptionsCGA.allCases.count
        #expect(cases.count == standardCount + cgaCount)
    }

    @Test("Standard theme description is correct")
    func standardDescription() {
        #expect(ThemeOption.standard(.dark).description == "Standard Dark")
        #expect(ThemeOption.standard(.light).description == "Standard Light")
        #expect(ThemeOption.standard(.auto).description == "Standard Auto")
    }

    @Test("CGA theme description is correct")
    func cgaDescription() {
        #expect(ThemeOption.cga(.blue).description == "CGA Blue")
        #expect(ThemeOption.cga(.red).description == "CGA Red")
    }

    @Test("Equality: same cases are equal")
    func equalitySame() {
        #expect(ThemeOption.standard(.dark) == ThemeOption.standard(.dark))
        #expect(ThemeOption.cga(.blue) == ThemeOption.cga(.blue))
    }

    @Test("Equality: different cases are not equal")
    func equalityDifferent() {
        #expect(ThemeOption.standard(.dark) != ThemeOption.standard(.light))
        #expect(ThemeOption.standard(.dark) != ThemeOption.cga(.blue))
    }

    @Test("ThemeOptionBridge serializes standard theme")
    func bridgeSerializesStandard() {
        let bridge = ThemeOptionBridge()
        let serialized = bridge.serialize(.standard(.dark))
        #expect(serialized != nil)
        #expect(serialized?["type"] == "standard")
        #expect(serialized?["value"] == "dark")
    }

    @Test("ThemeOptionBridge serializes CGA theme")
    func bridgeSerializesCGA() {
        let bridge = ThemeOptionBridge()
        let serialized = bridge.serialize(.cga(.green))
        #expect(serialized != nil)
        #expect(serialized?["type"] == "cga")
        #expect(serialized?["value"] == "green")
    }

    @Test("ThemeOptionBridge deserializes standard theme")
    func bridgeDeserializesStandard() {
        let bridge = ThemeOptionBridge()
        let dict = ["type": "standard", "value": "light"]
        let result = bridge.deserialize(dict)
        #expect(result == .standard(.light))
    }

    @Test("ThemeOptionBridge deserializes CGA theme")
    func bridgeDeserializesCGA() {
        let bridge = ThemeOptionBridge()
        let dict = ["type": "cga", "value": "magenta"]
        let result = bridge.deserialize(dict)
        #expect(result == .cga(.magenta))
    }

    @Test("ThemeOptionBridge round-trips all standard themes")
    func bridgeRoundTripStandard() {
        let bridge = ThemeOptionBridge()
        for theme in ThemeOptionsStandard.allCases {
            let option = ThemeOption.standard(theme)
            let serialized = bridge.serialize(option)
            let deserialized = bridge.deserialize(serialized)
            #expect(deserialized == option)
        }
    }

    @Test("ThemeOptionBridge round-trips all CGA themes")
    func bridgeRoundTripCGA() {
        let bridge = ThemeOptionBridge()
        for theme in ThemeOptionsCGA.allCases {
            let option = ThemeOption.cga(theme)
            let serialized = bridge.serialize(option)
            let deserialized = bridge.deserialize(serialized)
            #expect(deserialized == option)
        }
    }

    @Test("ThemeOptionBridge deserialize with nil returns nil")
    func bridgeDeserializeNil() {
        let bridge = ThemeOptionBridge()
        #expect(bridge.deserialize(nil) == nil)
    }

    @Test("ThemeOptionBridge deserialize with unknown type returns nil")
    func bridgeDeserializeUnknownType() {
        let bridge = ThemeOptionBridge()
        let dict = ["type": "unknown", "value": "dark"]
        #expect(bridge.deserialize(dict) == nil)
    }

    @Test("ThemeOptionBridge falls back to .dark for unknown standard rawValue")
    func bridgeStandardFallback() {
        let bridge = ThemeOptionBridge()
        let dict = ["type": "standard", "value": "nonexistent"]
        let result = bridge.deserialize(dict)
        #expect(result == .standard(.dark))
    }

    @Test("ThemeOptionBridge falls back to .blue for unknown CGA rawValue")
    func bridgeCGAFallback() {
        let bridge = ThemeOptionBridge()
        let dict = ["type": "cga", "value": "nonexistent"]
        let result = bridge.deserialize(dict)
        #expect(result == .cga(.blue))
    }

    @Test("ThemeOptionsStandard descriptions are capitalized rawValues")
    func standardDescriptions() {
        for theme in ThemeOptionsStandard.allCases {
            #expect(theme.description == theme.rawValue.capitalized)
        }
    }

    @Test("ThemeOptionsCGA descriptions are capitalized rawValues")
    func cgaDescriptions() {
        for theme in ThemeOptionsCGA.allCases {
            #expect(theme.description == theme.rawValue.capitalized)
        }
    }
}

// MARK: - SortOptions Tests

@Suite("SortOptions")
struct SortOptionsTests {

    @Test("All cases present")
    func allCasesCount() {
        #expect(SortOptions.allCases.count == 4)
        #expect(SortOptions.count == 4)
    }

    @Test("Descriptions are correct")
    func descriptions() {
        #expect(SortOptions.title.description == "Title")
        #expect(SortOptions.importDate.description == "Imported")
        #expect(SortOptions.lastPlayed.description == "Last Played")
        #expect(SortOptions.mostPlayed.description == "Most Played")
    }

    @Test("Row equals rawValue")
    func rowEqualsRawValue() {
        for option in SortOptions.allCases {
            #expect(option.row == option.rawValue)
        }
    }

    @Test("optionForRow returns correct cases")
    func optionForRow() {
        #expect(SortOptions.optionForRow(0) == .title)
        #expect(SortOptions.optionForRow(1) == .importDate)
        #expect(SortOptions.optionForRow(2) == .lastPlayed)
        #expect(SortOptions.optionForRow(3) == .mostPlayed)
    }

    @Test("optionForRow with invalid row returns title")
    func optionForRowInvalid() {
        #expect(SortOptions.optionForRow(99) == .title)
    }

    @Test("Identifiable id equals row")
    func identifiableId() {
        for option in SortOptions.allCases {
            #expect(option.id == option.row)
        }
    }

    @Test("RawValue round-trip")
    func rawValueRoundTrip() {
        for option in SortOptions.allCases {
            let reconstructed = SortOptions(rawValue: option.rawValue)
            #expect(reconstructed == option)
        }
    }
}

// MARK: - BoolSetting Tests

@Suite("BoolSetting")
struct BoolSettingTests {

    @Test("Init with true preserves defaultValue")
    func initWithTrue() {
        let setting = BoolSetting(true, title: "Test Setting")
        #expect(setting.defaultValue == true)
        #expect(setting.value == true)
    }

    @Test("Init with false preserves defaultValue")
    func initWithFalse() {
        let setting = BoolSetting(false, title: "Another Setting")
        #expect(setting.defaultValue == false)
        #expect(setting.value == false)
    }

    @Test("Title is stored correctly")
    func titleStored() {
        let setting = BoolSetting(true, title: "My Title")
        #expect(setting.title == "My Title")
    }

    @Test("Info is stored correctly")
    func infoStored() {
        let setting = BoolSetting(true, title: "Test", info: "Some info")
        #expect(setting.info == "Some info")
    }

    @Test("Info defaults to nil")
    func infoDefaultsToNil() {
        let setting = BoolSetting(true, title: "Test")
        #expect(setting.info == nil)
    }

    @Test("Value can be mutated")
    func valueMutable() {
        var setting = BoolSetting(true, title: "Mutable")
        #expect(setting.value == true)
        setting.value = false
        #expect(setting.value == false)
        #expect(setting.defaultValue == true, "defaultValue should not change")
    }

    @Test("defaultsValue returns current value as Any")
    func defaultsValue() {
        let setting = BoolSetting(true, title: "Test")
        let defaultsValue = setting.defaultsValue
        guard let boolValue = defaultsValue as? Bool else {
            Issue.record("Expected Bool from defaultsValue")
            return
        }
        #expect(boolValue == true)
    }

    @Test("valueType is Bool")
    func valueType() {
        let setting = BoolSetting(true, title: "Test")
        #expect(setting.valueType == Bool.self)
    }
}

// MARK: - SkinMode Tests

@Suite("SkinMode")
struct SkinModeTests {

    @Test("All cases present")
    func allCasesCount() {
        #expect(SkinMode.allCases.count == 3)
    }

    @Test("RawValue round-trip")
    func rawValueRoundTrip() {
        for mode in SkinMode.allCases {
            let reconstructed = SkinMode(rawValue: mode.rawValue)
            #expect(reconstructed == mode)
        }
    }

    @Test("Identifiable id equals rawValue")
    func identifiableId() {
        for mode in SkinMode.allCases {
            #expect(mode.id == mode.rawValue)
        }
    }

    @Test("Descriptions are non-empty")
    func descriptionsNonEmpty() {
        for mode in SkinMode.allCases {
            #expect(!mode.description.isEmpty)
        }
    }

    @Test("Subtitles are non-empty")
    func subtitlesNonEmpty() {
        for mode in SkinMode.allCases {
            #expect(!mode.subtitle.isEmpty)
        }
    }
}

@Suite("SkinMode Defaults Migration", .serialized)
struct SkinModeDefaultsMigrationTests {
    /// Removes both canonical and legacy skin-mode keys between migration tests.
    private func clearSkinModeDefaults() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: canonicalSkinModeDefaultsKey)
        defaults.removeObject(forKey: legacySkinModeDefaultsKey)
    }

    @Test("Migrates the legacy skinMode key to the canonical key")
    func migrateLegacySkinModeKey() {
        clearSkinModeDefaults()
        defer { clearSkinModeDefaults() }

        UserDefaults.standard.set(SkinMode.always.rawValue, forKey: legacySkinModeDefaultsKey)
        migrateLegacySkinModeIfNeeded()

        #expect(UserDefaults.standard.string(forKey: canonicalSkinModeDefaultsKey) == SkinMode.always.rawValue)
    }

    @Test("Canonical skinMode value wins over the legacy key")
    func canonicalSkinModeWins() {
        clearSkinModeDefaults()
        defer { clearSkinModeDefaults() }

        UserDefaults.standard.set(SkinMode.selectedOnly.rawValue, forKey: canonicalSkinModeDefaultsKey)
        UserDefaults.standard.set(SkinMode.off.rawValue, forKey: legacySkinModeDefaultsKey)
        migrateLegacySkinModeIfNeeded()

        #expect(UserDefaults.standard.string(forKey: canonicalSkinModeDefaultsKey) == SkinMode.selectedOnly.rawValue)
    }

    @Test("SelectedOnly subtitle keeps the corrected spelling")
    func selectedOnlySubtitleSpelling() {
        #expect(SkinMode.selectedOnly.subtitle == "Use skins for selected systems, use classic controller as default")
    }
}

@Suite("RetroAchievements Defaults Migration", .serialized)
struct RetroAchievementsDefaultsMigrationTests {
    /// Removes canonical and legacy RetroAchievements keys between migration tests.
    private func clearRetroAchievementsDefaults() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: canonicalRetroAchievementsEnabledDefaultsKey)
        defaults.removeObject(forKey: legacyRetroAchievementsEnabledDefaultsKey)
        defaults.removeObject(forKey: canonicalRetroAchievementsHardcoreDefaultsKey)
        defaults.removeObject(forKey: legacyRetroAchievementsHardcoreDefaultsKey)
    }

    @Test("Migrates the legacy RetroAchievements enabled key")
    func migrateLegacyRetroAchievementsEnabledKey() {
        clearRetroAchievementsDefaults()
        defer { clearRetroAchievementsDefaults() }

        UserDefaults.standard.set(true, forKey: legacyRetroAchievementsEnabledDefaultsKey)
        migrateLegacyBoolPreferenceIfNeeded(
            primaryKey: canonicalRetroAchievementsEnabledDefaultsKey,
            legacyKey: legacyRetroAchievementsEnabledDefaultsKey
        )

        #expect(UserDefaults.standard.bool(forKey: canonicalRetroAchievementsEnabledDefaultsKey) == true)
    }

    @Test("Migrates the legacy RetroAchievements hardcore key")
    func migrateLegacyRetroAchievementsHardcoreKey() {
        clearRetroAchievementsDefaults()
        defer { clearRetroAchievementsDefaults() }

        UserDefaults.standard.set(true, forKey: legacyRetroAchievementsHardcoreDefaultsKey)
        migrateLegacyBoolPreferenceIfNeeded(
            primaryKey: canonicalRetroAchievementsHardcoreDefaultsKey,
            legacyKey: legacyRetroAchievementsHardcoreDefaultsKey
        )

        #expect(UserDefaults.standard.bool(forKey: canonicalRetroAchievementsHardcoreDefaultsKey) == true)
    }
}

// MARK: - MouseInputSource Tests

@Suite("MouseInputSource")
struct MouseInputSourceTests {

    @Test("All cases present")
    func allCasesCount() {
        #expect(MouseInputSource.allCases.count == 5)
    }

    @Test("RawValue round-trip")
    func rawValueRoundTrip() {
        for source in MouseInputSource.allCases {
            let reconstructed = MouseInputSource(rawValue: source.rawValue)
            #expect(reconstructed == source)
        }
    }

    @Test("RawValues are correct")
    func rawValues() {
        #expect(MouseInputSource.auto.rawValue == "auto")
        #expect(MouseInputSource.touchscreen.rawValue == "touchscreen")
        #expect(MouseInputSource.controllerTouchpad.rawValue == "controllerTouchpad")
        #expect(MouseInputSource.gyro.rawValue == "gyro")
        #expect(MouseInputSource.physicalMouse.rawValue == "physicalMouse")
    }

    @Test("DisplayNames are non-empty")
    func displayNamesNonEmpty() {
        for source in MouseInputSource.allCases {
            #expect(!source.displayName.isEmpty)
        }
    }

    @Test("Subtitles are non-empty")
    func subtitlesNonEmpty() {
        for source in MouseInputSource.allCases {
            #expect(!source.subtitle.isEmpty)
        }
    }

    @Test("SymbolNames are non-empty")
    func symbolNamesNonEmpty() {
        for source in MouseInputSource.allCases {
            #expect(!source.symbolName.isEmpty)
        }
    }

    @Test("Equality works correctly")
    func equality() {
        #expect(MouseInputSource.auto == .auto)
        #expect(MouseInputSource.auto != .gyro)
    }

    @Test("Invalid rawValue returns nil")
    func invalidRawValueReturnsNil() {
        #expect(MouseInputSource(rawValue: "nonexistent") == nil)
    }
}

// MARK: - LightGunCrosshairStyle Tests

@Suite("LightGunCrosshairStyle")
struct LightGunCrosshairStyleTests {

    @Test("All cases present")
    func allCasesCount() {
        #expect(LightGunCrosshairStyle.allCases.count == 4)
    }

    @Test("RawValue round-trip")
    func rawValueRoundTrip() {
        for style in LightGunCrosshairStyle.allCases {
            let reconstructed = LightGunCrosshairStyle(rawValue: style.rawValue)
            #expect(reconstructed == style)
        }
    }

    @Test("RawValues are correct")
    func rawValues() {
        #expect(LightGunCrosshairStyle.off.rawValue == "off")
        #expect(LightGunCrosshairStyle.dot.rawValue == "dot")
        #expect(LightGunCrosshairStyle.crosshair.rawValue == "crosshair")
        #expect(LightGunCrosshairStyle.reticle.rawValue == "reticle")
    }

    @Test("DisplayNames are non-empty")
    func displayNamesNonEmpty() {
        for style in LightGunCrosshairStyle.allCases {
            #expect(!style.displayName.isEmpty)
        }
    }

    @Test("Subtitles are non-empty")
    func subtitlesNonEmpty() {
        for style in LightGunCrosshairStyle.allCases {
            #expect(!style.subtitle.isEmpty)
        }
    }

    @Test("SymbolNames are non-empty")
    func symbolNamesNonEmpty() {
        for style in LightGunCrosshairStyle.allCases {
            #expect(!style.symbolName.isEmpty)
        }
    }

    @Test("Invalid rawValue returns nil")
    func invalidRawValueReturnsNil() {
        #expect(LightGunCrosshairStyle(rawValue: "nonexistent") == nil)
    }
}

// MARK: - LightGunCrosshairStyle Defaults Key Tests

@Suite("LightGunCrosshairStyle Defaults Key", .serialized)
struct LightGunCrosshairStyleDefaultsTests {

    @Test("lightGunCrosshairStyle default is .crosshair")
    func defaultIsCrosshair() {
        Defaults.reset(.lightGunCrosshairStyle)
        #expect(Defaults[.lightGunCrosshairStyle] == .crosshair)
    }

    @Test("lightGunCrosshairStyle key name is correct")
    func keyName() {
        #expect(Defaults.Keys.lightGunCrosshairStyle.name == "lightGunCrosshairStyle")
    }

    @Test("lightGunCrosshairStyle can be mutated and reset")
    func mutable() {
        Defaults.reset(.lightGunCrosshairStyle)
        defer { Defaults.reset(.lightGunCrosshairStyle) }
        Defaults[.lightGunCrosshairStyle] = .off
        #expect(Defaults[.lightGunCrosshairStyle] == .off)
        Defaults.reset(.lightGunCrosshairStyle)
        #expect(Defaults[.lightGunCrosshairStyle] == .crosshair)
    }
}

// MARK: - Mouse Defaults Keys Tests

@Suite("Mouse Defaults Keys", .serialized)
struct MouseDefaultsKeysTests {

    @Test("mouseInputSource default is .auto")
    func mouseInputSourceDefault() {
        Defaults.reset(.mouseInputSource)
        #expect(Defaults[.mouseInputSource] == .auto)
    }

    @Test("mouseSensitivity default is 1.0")
    func mouseSensitivityDefault() {
        Defaults.reset(.mouseSensitivity)
        #expect(Defaults[.mouseSensitivity] == 1.0)
    }

    @Test("mouseInputSource key name is correct")
    func mouseInputSourceKeyName() {
        #expect(Defaults.Keys.mouseInputSource.name == "mouseInputSource")
    }

    @Test("mouseSensitivity key name is correct")
    func mouseSensitivityKeyName() {
        #expect(Defaults.Keys.mouseSensitivity.name == "mouseSensitivity")
    }

    @Test("mouseInputSource can be changed and reset")
    func mouseInputSourceMutable() {
        Defaults.reset(.mouseInputSource)
        defer { Defaults.reset(.mouseInputSource) }
        Defaults[.mouseInputSource] = .gyro
        #expect(Defaults[.mouseInputSource] == .gyro)
        Defaults.reset(.mouseInputSource)
        #expect(Defaults[.mouseInputSource] == .auto)
    }

    @Test("mouseSensitivity can be changed")
    func mouseSensitivityMutable() {
        Defaults.reset(.mouseSensitivity)
        defer { Defaults.reset(.mouseSensitivity) }
        Defaults[.mouseSensitivity] = 2.5
        #expect(Defaults[.mouseSensitivity] == 2.5)
    }
}

// MARK: - iCloudSyncMode Tests

@Suite("iCloudSyncMode")
struct iCloudSyncModeTests {

    @Test("CloudKit is isCloudKit")
    func cloudKitIsCloudKit() {
        #expect(iCloudSyncMode.cloudKit.isCloudKit)
    }

    @Test("CloudKit isICloudDrive is false")
    func cloudKitIsNotICloudDrive() {
        #expect(!iCloudSyncMode.cloudKit.isICloudDrive)
    }

    @Test("CloudKit description is 'CloudKit'")
    func cloudKitDescription() {
        #expect(iCloudSyncMode.cloudKit.description == "CloudKit")
    }

    @Test("CloudKit subtitle is non-empty")
    func cloudKitSubtitleNonEmpty() {
        #expect(!iCloudSyncMode.cloudKit.subtitle.isEmpty)
    }

    @Test("RawValue round-trip for cloudKit")
    func rawValueRoundTrip() {
        let mode = iCloudSyncMode.cloudKit
        let reconstructed = iCloudSyncMode(rawValue: mode.rawValue)
        #expect(reconstructed == mode)
    }
}

// MARK: - Physical Case Controller Defaults Tests

#if os(iOS) || targetEnvironment(macCatalyst)
@Suite("Physical Case Controller Defaults")
struct PhysicalCaseControllerDefaultsTests {

    @Test("autoLoadCaseSkin default is true")
    func autoLoadCaseSkinDefault() {
        Defaults.reset(.autoLoadCaseSkin)
        #expect(Defaults[.autoLoadCaseSkin] == true)
    }

    @Test("autoLoadCaseSkin key name is correct")
    func autoLoadCaseSkinKeyName() {
        #expect(Defaults.Keys.autoLoadCaseSkin.name == "autoLoadCaseSkin")
    }

    @Test("autoLoadCaseSkin resets to default after change")
    func autoLoadCaseSkinReset() {
        Defaults[.autoLoadCaseSkin] = false
        #expect(Defaults[.autoLoadCaseSkin] == false)
        Defaults.reset(.autoLoadCaseSkin)
        #expect(Defaults[.autoLoadCaseSkin] == true)
    }
}
#endif

// MARK: - Gyro Mouse Defaults Tests

@Suite("Gyro Mouse Defaults", .serialized)
struct GyroMouseDefaultsTests {

    @Test("gyroMouseEnabled default is false")
    func gyroMouseEnabledDefault() {
        Defaults.reset(.gyroMouseEnabled)
        #expect(Defaults[.gyroMouseEnabled] == false)
    }

    @Test("gyroMouseSensitivity default is 1.0")
    func gyroMouseSensitivityDefault() {
        Defaults.reset(.gyroMouseSensitivity)
        #expect(Defaults[.gyroMouseSensitivity] == 1.0)
    }

    @Test("gyroMouseDeadZone default is 0.05")
    func gyroMouseDeadZoneDefault() {
        Defaults.reset(.gyroMouseDeadZone)
        #expect(Defaults[.gyroMouseDeadZone] == 0.05)
    }

    @Test("gyroMouseEnabled key name is correct")
    func gyroMouseEnabledKeyName() {
        #expect(Defaults.Keys.gyroMouseEnabled.name == "gyroMouseEnabled")
    }

    @Test("gyroMouseSensitivity key name is correct")
    func gyroMouseSensitivityKeyName() {
        #expect(Defaults.Keys.gyroMouseSensitivity.name == "gyroMouseSensitivity")
    }

    @Test("gyroMouseDeadZone key name is correct")
    func gyroMouseDeadZoneKeyName() {
        #expect(Defaults.Keys.gyroMouseDeadZone.name == "gyroMouseDeadZone")
    }

    @Test("gyroMouseEnabled can be toggled")
    func gyroMouseEnabledToggle() {
        Defaults.reset(.gyroMouseEnabled)
        defer { Defaults.reset(.gyroMouseEnabled) }
        Defaults[.gyroMouseEnabled] = true
        #expect(Defaults[.gyroMouseEnabled] == true)
        Defaults[.gyroMouseEnabled] = false
        #expect(Defaults[.gyroMouseEnabled] == false)
    }

    @Test("gyroMouseSensitivity persists to UserDefaults")
    func gyroMouseSensitivityPersists() {
        Defaults.reset(.gyroMouseSensitivity)
        defer { Defaults.reset(.gyroMouseSensitivity) }
        Defaults[.gyroMouseSensitivity] = 2.5
        let raw = UserDefaults.standard.double(forKey: "gyroMouseSensitivity")
        #expect(raw == 2.5)
    }

    @Test("gyroMouseDeadZone can be changed")
    func gyroMouseDeadZoneMutable() {
        Defaults.reset(.gyroMouseDeadZone)
        defer { Defaults.reset(.gyroMouseDeadZone) }
        Defaults[.gyroMouseDeadZone] = 0.1
        #expect(Defaults[.gyroMouseDeadZone] == 0.1)
    }

    @Test("gyroMouseDeadZone default is within valid slider range")
    func gyroMouseDeadZoneDefaultWithinValidRange() {
        Defaults.reset(.gyroMouseDeadZone)
        let value = Defaults[.gyroMouseDeadZone]
        // Valid range matches the UI slider: 0.0...0.5
        #expect(value >= 0.0)
        #expect(value <= 0.5)
    }

    @Test("gyroMouseDeadZone boundary values are within valid range")
    func gyroMouseDeadZoneBoundaryValues() {
        Defaults.reset(.gyroMouseDeadZone)
        defer { Defaults.reset(.gyroMouseDeadZone) }

        Defaults[.gyroMouseDeadZone] = 0.0
        #expect(Defaults[.gyroMouseDeadZone] == 0.0)

        Defaults[.gyroMouseDeadZone] = 0.5
        #expect(Defaults[.gyroMouseDeadZone] == 0.5)
    }
}

// MARK: - External Display Mode Tests

@Suite("External Display Mode Defaults", .serialized)
struct ExternalDisplayModeTests {

    @Test("externalDisplayMode default is systemMirror")
    func externalDisplayModeDefault() {
        Defaults.reset(.externalDisplayMode)
        #expect(Defaults[.externalDisplayMode] == .systemMirror)
    }

    @Test("externalDisplayMode key name is correct")
    func externalDisplayModeKeyName() {
        #expect(Defaults.Keys.externalDisplayMode.name == "externalDisplayMode")
    }

    @Test("externalDisplayMode can be set to dedicated and reset")
    func externalDisplayModeMutable() {
        Defaults.reset(.externalDisplayMode)
        defer { Defaults.reset(.externalDisplayMode) }
        Defaults[.externalDisplayMode] = .dedicated
        #expect(Defaults[.externalDisplayMode] == .dedicated)
        Defaults.reset(.externalDisplayMode)
        #expect(Defaults[.externalDisplayMode] == .systemMirror)
    }

    @Test("ExternalDisplayMode rawValues are stable")
    func externalDisplayModeRawValues() {
        #expect(ExternalDisplayMode.systemMirror.rawValue == "systemMirror")
        #expect(ExternalDisplayMode.dedicated.rawValue == "dedicated")
    }

    @Test("ExternalDisplayMode has exactly two cases")
    func externalDisplayModeCaseCount() {
        #expect(ExternalDisplayMode.allCases.count == 2)
    }
}

// MARK: - CoreLanguageSetting Tests

@Suite("CoreLanguageSetting")
struct CoreLanguageSettingTests {

    @Test("default coreLanguage is systemLocale")
    func coreLanguageDefault() {
        Defaults.reset(.coreLanguage)
        #expect(Defaults[.coreLanguage] == .systemLocale)
    }

    @Test("explicit override round-trips through Defaults")
    func coreLanguageExplicitOverride() {
        Defaults.reset(.coreLanguage)
        defer { Defaults.reset(.coreLanguage) }
        Defaults[.coreLanguage] = .japanese
        #expect(Defaults[.coreLanguage] == .japanese)
        Defaults.reset(.coreLanguage)
        #expect(Defaults[.coreLanguage] == .systemLocale)
    }

    @Test("systemLocale raw value is -1")
    func systemLocaleRawValue() {
        #expect(CoreLanguageSetting.systemLocale.rawValue == -1)
    }

    @Test("retroArchLanguageID is nil for systemLocale")
    func retroArchLanguageIDSystemLocale() {
        #expect(CoreLanguageSetting.systemLocale.retroArchLanguageID == nil)
    }

    @Test("retroArchLanguageID matches raw value for explicit languages")
    func retroArchLanguageIDExplicit() {
        #expect(CoreLanguageSetting.english.retroArchLanguageID == 0)
        #expect(CoreLanguageSetting.japanese.retroArchLanguageID == 1)
        #expect(CoreLanguageSetting.french.retroArchLanguageID == 2)
        #expect(CoreLanguageSetting.chineseSimplified.retroArchLanguageID == 11)
        #expect(CoreLanguageSetting.russian.retroArchLanguageID == 16)
    }

    @Test("allCases contains systemLocale and all explicit languages")
    func allCasesCount() {
        #expect(CoreLanguageSetting.allCases.contains(.systemLocale))
        #expect(CoreLanguageSetting.allCases.count >= 17)
    }
}

// MARK: - Light Gun Settings Tests

@Suite("Light Gun Settings")
struct LightGunSettingsTests {

    // MARK: - LightGunCrosshairStyle

    @Test("LightGunCrosshairStyle has three cases")
    func crosshairStyleCaseCount() {
        #expect(LightGunCrosshairStyle.allCases.count == 3)
    }

    @Test("LightGunCrosshairStyle rawValues are stable")
    func crosshairStyleRawValues() {
        #expect(LightGunCrosshairStyle.dot.rawValue == "dot")
        #expect(LightGunCrosshairStyle.crosshair.rawValue == "crosshair")
        #expect(LightGunCrosshairStyle.off.rawValue == "off")
    }

    // MARK: - LightGunMode

    @Test("LightGunMode has three cases")
    func lightGunModeCaseCount() {
        #expect(LightGunMode.allCases.count == 3)
    }

    @Test("LightGunMode rawValues are stable")
    func lightGunModeRawValues() {
        #expect(LightGunMode.automatic.rawValue == "automatic")
        #expect(LightGunMode.enabled.rawValue == "enabled")
        #expect(LightGunMode.disabled.rawValue == "disabled")
    }

    // MARK: - LightGunGameSettings

    @Test("LightGunGameSettings default values")
    func lightGunGameSettingsDefaults() {
        let settings = LightGunGameSettings()
        #expect(settings.mode == .automatic)
        #expect(settings.crosshairStyle == nil)
        #expect(settings.sensitivityOverride == nil)
        #expect(settings.isDefault == true)
    }

    @Test("LightGunGameSettings isDefault false when mode overridden")
    func lightGunGameSettingsNotDefaultWhenModeSet() {
        let settings = LightGunGameSettings(mode: .enabled)
        #expect(settings.isDefault == false)
    }

    @Test("LightGunGameSettings isDefault false when crosshair overridden")
    func lightGunGameSettingsNotDefaultWhenCrosshairSet() {
        let settings = LightGunGameSettings(crosshairStyle: .dot)
        #expect(settings.isDefault == false)
    }

    @Test("LightGunGameSettings isDefault false when sensitivity overridden")
    func lightGunGameSettingsNotDefaultWhenSensitivitySet() {
        let settings = LightGunGameSettings(sensitivityOverride: 2.0)
        #expect(settings.isDefault == false)
    }

    // MARK: - Defaults Keys

    @Test("lightGunCrosshairStyle default is crosshair")
    func lightGunCrosshairStyleDefault() {
        Defaults.reset(.lightGunCrosshairStyle)
        defer { Defaults.reset(.lightGunCrosshairStyle) }
        #expect(Defaults[.lightGunCrosshairStyle] == .crosshair)
    }

    @Test("lightGunAutoDetect default is true")
    func lightGunAutoDetectDefault() {
        Defaults.reset(.lightGunAutoDetect)
        defer { Defaults.reset(.lightGunAutoDetect) }
        #expect(Defaults[.lightGunAutoDetect] == true)
    }

    @Test("lightGunGameSettings default is empty dictionary")
    func lightGunGameSettingsDefaultEmpty() {
        Defaults.reset(.lightGunGameSettings)
        defer { Defaults.reset(.lightGunGameSettings) }
        #expect(Defaults[.lightGunGameSettings].isEmpty)
    }

    // MARK: - Defaults Helpers

    @Test("lightGunSettings returns default for unknown MD5")
    func lightGunSettingsDefaultForUnknownMD5() {
        Defaults.reset(.lightGunGameSettings)
        defer { Defaults.reset(.lightGunGameSettings) }
        let settings = Defaults.lightGunSettings(forGameMD5: "unknownmd5hash")
        #expect(settings.isDefault)
    }

    @Test("setLightGunSettings persists and retrieves settings")
    func setAndGetLightGunSettings() {
        Defaults.reset(.lightGunGameSettings)
        defer { Defaults.reset(.lightGunGameSettings) }
        let md5 = "testmd5abc"
        let custom = LightGunGameSettings(mode: .enabled, crosshairStyle: .dot, sensitivityOverride: 2.5)
        Defaults.setLightGunSettings(custom, forGameMD5: md5)
        let retrieved = Defaults.lightGunSettings(forGameMD5: md5)
        #expect(retrieved.mode == .enabled)
        #expect(retrieved.crosshairStyle == .dot)
        #expect(retrieved.sensitivityOverride == 2.5)
    }

    @Test("setLightGunSettings removes entry when set to defaults")
    func setLightGunSettingsRemovesWhenDefault() {
        Defaults.reset(.lightGunGameSettings)
        defer { Defaults.reset(.lightGunGameSettings) }
        let md5 = "testmd5def"
        Defaults.setLightGunSettings(LightGunGameSettings(mode: .enabled), forGameMD5: md5)
        #expect(!Defaults[.lightGunGameSettings].isEmpty)
        Defaults.setLightGunSettings(LightGunGameSettings(), forGameMD5: md5)
        #expect(Defaults[.lightGunGameSettings][md5] == nil)
    }

    @Test("effectiveCrosshairStyle uses per-game override when set")
    func effectiveCrosshairStyleUsesPerGameOverride() {
        Defaults.reset(.lightGunGameSettings)
        Defaults.reset(.lightGunCrosshairStyle)
        defer {
            Defaults.reset(.lightGunGameSettings)
            Defaults.reset(.lightGunCrosshairStyle)
        }
        let md5 = "testmd5ghi"
        Defaults[.lightGunCrosshairStyle] = .crosshair
        Defaults.setLightGunSettings(LightGunGameSettings(crosshairStyle: .off), forGameMD5: md5)
        #expect(Defaults.effectiveCrosshairStyle(forGameMD5: md5) == .off)
    }

    @Test("effectiveCrosshairStyle falls back to global when no per-game override")
    func effectiveCrosshairStyleFallsBackToGlobal() {
        Defaults.reset(.lightGunGameSettings)
        Defaults.reset(.lightGunCrosshairStyle)
        defer {
            Defaults.reset(.lightGunGameSettings)
            Defaults.reset(.lightGunCrosshairStyle)
        }
        let md5 = "testmd5jkl"
        Defaults[.lightGunCrosshairStyle] = .dot
        #expect(Defaults.effectiveCrosshairStyle(forGameMD5: md5) == .dot)
    }

    @Test("effectiveLightGunSensitivity uses per-game override when set")
    func effectiveSensitivityUsesPerGameOverride() {
        Defaults.reset(.lightGunGameSettings)
        Defaults.reset(.lightGunMouseSensitivity)
        defer {
            Defaults.reset(.lightGunGameSettings)
            Defaults.reset(.lightGunMouseSensitivity)
        }
        let md5 = "testmd5mno"
        Defaults[.lightGunMouseSensitivity] = 1.0
        Defaults.setLightGunSettings(LightGunGameSettings(sensitivityOverride: 3.0), forGameMD5: md5)
        #expect(Defaults.effectiveLightGunSensitivity(forGameMD5: md5) == 3.0)
    }

    @Test("effectiveLightGunSensitivity falls back to global when no per-game override")
    func effectiveSensitivityFallsBackToGlobal() {
        Defaults.reset(.lightGunGameSettings)
        Defaults.reset(.lightGunMouseSensitivity)
        defer {
            Defaults.reset(.lightGunGameSettings)
            Defaults.reset(.lightGunMouseSensitivity)
        }
        let md5 = "testmd5pqr"
        Defaults[.lightGunMouseSensitivity] = 2.0
        #expect(Defaults.effectiveLightGunSensitivity(forGameMD5: md5) == 2.0)
    }
}

