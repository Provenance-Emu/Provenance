import Foundation

extension PVPlayCore: CoreOptional {
 	static var resolutionOption: CoreOption = {
 	 	.enumeration(.init(title: "Resolution Upscaling",
 	 	 	 	 	 	 	 	description: "(Requires Restart)",
 	 	 	 	 	 	 	 	requiresRestart: true),
 	 	 	 	 	 	 	values: [
 	 	 	 	 	 	 	 	.init(title: "1X", description: "1X", value: 1),
 	 	 	 	 	 	 	 	.init(title: "2X", description: "2X", value: 2),
 	 	 	 	 	 	 	 	.init(title: "3X", description: "3X", value: 3),
 	 	 	 	 	 	 	 	.init(title: "4X", description: "4X", value: 4),
 	 	 	 	 	 	 	 	.init(title: "5X", description: "5X", value: 5),
 	 	 	 	 	 	 	 	.init(title: "6X", description: "6X", value: 6),
 	 	 	 	 	 	 	 	.init(title: "7X", description: "7X", value: 7),
 	 	 	 	 	 	 	 	.init(title: "8X", description: "8X", value: 8),
 	 	 	 	 	 	 	 	.init(title: "16X", description: "16X", value: 16),
 	 	 	 	 	 	 	],
 	 	 	 	 	 	 	defaultValue: 1)
 	}()
 	public static var options: [CoreOption] {
		var options = [CoreOption]()
 	 	var coreOptions = [CoreOption]()
 	 	coreOptions.append(resolutionOption)
		let coreGroup:CoreOption = .group(.init(title: "Play! Core", description: "Global options for Play!"),
										  subOptions: coreOptions)
 	 	options.append(contentsOf: [coreGroup])
		return options
	}
}

@objc public extension PVPlayCore {
 	@objc var resolution: Int{
 	 	PVPlayCore.valueForOption(PVPlayCore.resolutionOption).asInt ?? 0
 	}
 	func parseOptions() {
 	 	self.resFactor = NSNumber(value: resolution).int8Value
 	}
}
