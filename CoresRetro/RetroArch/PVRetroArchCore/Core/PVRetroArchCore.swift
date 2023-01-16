import Foundation
extension PVRetroArchCore: GameWithCheat {
	@objc public func setCheat(code: String, type: String, codeType: String, cheatIndex: UInt8, enabled: Bool) -> Bool {
		do {
			ILOG("Calling setCheat \(code) \(type) \(codeType)")
			try self.setCheat(code, setType: type, setCodeType: codeType, setIndex: cheatIndex, setEnabled: enabled)
			return true
		} catch let error {
			ILOG("Error setCheat \(error)")
			return false
		}
	}

    public var supportsCheatCode: Bool {
		return true
	}

    public var cheatCodeTypes: [String] {
		return []
	}
}
