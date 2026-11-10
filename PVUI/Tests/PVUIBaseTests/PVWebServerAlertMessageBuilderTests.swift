//
//  PVWebServerAlertMessageBuilderTests.swift
//  PVUIBaseTests
//

import XCTest
@testable import PVUIBase

final class PVWebServerAlertMessageBuilderTests: XCTestCase {

    func testSharedAddressIsListedOnce() {
        let url = "http://192.168.1.20/"
        let message = PVWebServerAlertMessageBuilder.wikiMessage(http: url, dav: url)
        XCTAssertEqual(message.components(separatedBy: url).count - 1, 1)
        XCTAssertTrue(message.contains("ᵂᵉᵇᴰᴬⱽ"))
    }

    func testDifferentAddressesAreBothListed() {
        let message = PVWebServerAlertMessageBuilder.wikiMessage(http: "http://a/", dav: "http://b/")
        XCTAssertTrue(message.contains("http://a/  ᵂᵉᵇᵁᴵ"))
        XCTAssertTrue(message.contains("http://b/  ᵂᵉᵇᴰᴬⱽ"))
    }
}
