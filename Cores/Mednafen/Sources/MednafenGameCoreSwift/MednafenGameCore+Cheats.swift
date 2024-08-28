import Foundation
import PVSupport
import PVEmulatorCore
import PVLogging
import PVLoggingObjC
import MednafenGameCoreC

class CppString {
    private var cppStringPtr: UnsafeMutableRawPointer

    init(_ swiftString: String) {
        let cString = swiftStringToCppString(swiftString)
        cppStringPtr = createCppString(cString)
    }

    deinit {
        deleteCppString(cppStringPtr)
    }

    func getCPPString() -> UnsafePointer<CChar> {
        return getCppStringContents(cppStringPtr)!
    }
    
    func getString() -> String {
        let cString = getCppStringContents(cppStringPtr)!
        return String(cString: cString)
    }
}

//@objc public protocol MednafenGameCoreCheatSyntax: NSObjectProtocol {
//    @objc func getCheatCodeTypes() -> [String]
//    @objc func setCheat(_ code: String, setType type: String, setCodeType codeType: String, setIndex cheatIndex: UInt8, setEnabled enabled: Bool) throws -> Bool
//    @objc func getCheatSupport() -> Bool
//}

@objc public enum MednafenCheatError: Int, Error {
    case invalidCode
    case invalidType
    case invalidCodeType
    case cheatsNotSupportedOnCurrentPlatform
}

@objc extension MednafenGameCore {
    
    @objc public func setCheat(_ code: String, setType type: String, setCodeType codeType: String, setIndex cheatIndex: UInt8, setEnabled enabled: Bool) throws {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        
        guard getCheatSupport() else {
            throw MednafenCheatError.cheatsNotSupportedOnCurrentPlatform
        }
        
        ILOG("Applying Cheat Code \(code) \(type)")     
        
        let game = getGame()?.assumingMemoryBound(to: Mednafen.MDFNGI.self)
        let multipleCodes = code.components(separatedBy: "+")
        ILOG("Multiple Codes \(multipleCodes) at INDEX \(cheatIndex)")
        
        for (var i, singleCode) in multipleCodes.enumerated() {
            guard !singleCode.isEmpty else { continue }
            
            ILOG("Applying Code \(singleCode)")
            var cheatCode = singleCode.replacingOccurrences(of: ":", with: "")
            var patch = Mednafen.MemoryPatch()
            
            do {
                if let game = game, game.pointee.CheatInfo.pointee.CheatFormatInfo.pointee.size() > 0 {
                    var formatIndex: UInt8 = 0
                    
                    switch systemType {
                    case .gb:
                        formatIndex = codeType == "Game Genie" ? 0 : 1
                    case .psx:
                        if codeType == "GameShark" {
                            formatIndex = 0
                            if i + 1 < multipleCodes.count, multipleCodes[i + 1].count == 4 {
                                cheatCode = singleCode + multipleCodes[i + 1]
                                i += 1
                            }
                        }
                    case .snes:
                        formatIndex = (codeType == "Game Genie" || singleCode.contains("-")) ? 0 : 1
                    default:
                        break
                    }
                    
#warning("TODO: Fix Swift String to C++ std::string")
                    
//                    let decoded = game.pointee.CheatInfo.pointee.CheatFormatInfo.pointee[Int(formatIndex)].DecodeCheat(cheatCode.cString(using: .utf8)!, &patch)
//                    
//                    if !decoded {
//                        throw MednafenCheatError.invalidCode
//                    }
//                    patch.status = enabled
                    
                    if cheatIndex < Mednafen.MDFNI_CheatSearchGetCount() {
                        Mednafen.MDFNI_SetCheat(uint32(cheatIndex), patch)
                        Mednafen.MDFNI_ToggleCheat(uint32(cheatIndex))
                    } else {
                        Mednafen.MDFNI_AddCheat(patch)
                    }
                }
            } catch {
                ILOG("Game Code Error \(error.localizedDescription)")
                throw error
            }
        }
        
        Mednafen.MDFNMP_ApplyPeriodicCheats()
    }
    
    @objc public func getCheatCodeTypes() -> [String] {
        switch systemType {
        case .gb:
            return ["Game Genie", "GameShark"]
        case .psx:
            return ["GameShark"]
        case .snes:
            return ["Game Genie", "Pro Action Replay"]
        default:
            return []
        }
    }
    
    @objc public func getCheatSupport() -> Bool {
        return systemType == .psx || systemType == .snes || systemType == .gb
    }
}
