pvsupport:
	@echo "Creating pvsupport"
	swift build -Xswiftc "-sdk" -Xswiftc "`xcrun --sdk iphonesimulator --show-sdk-path`" -Xswiftc "-target" -Xswiftc "x86_64-apple-ios13.0-simulator"

pvsupport-watchOS:
	@echo "Creating pvsupport"
	swift build -Xswiftc "-sdk" -Xswiftc "`xcrun --sdk applewatchsimulator --show-sdk-path`" -Xswiftc "-target" -Xswiftc "x86_64-apple-watchos8.0-simulator"

pvsupport-tvOS:
	@echo "Creating pvsupport"
	swift build -Xswiftc "-sdk" -Xswiftc "`xcrun --sdk appletvsimulator --show-sdk-path`" -Xswiftc "-target" -Xswiftc "x86_64-apple-tvos13.0-simulator"

pvsupport-macOS:
	@echo "Creating pvsupport"
	swift build -Xswiftc "-sdk" -Xswiftc "`xcrun --sdk macOS --show-sdk-path`" -Xswiftc "-target" -Xswiftc "x86_64-apple-macos12.0-simulator"
