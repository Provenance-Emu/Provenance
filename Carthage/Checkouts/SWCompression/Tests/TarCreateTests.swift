// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import XCTest
import SWCompression

class TarCreateTests: XCTestCase {

    func test1() throws {
        var info = TarEntryInfo(name: "file.txt", type: .regular)
        info.ownerUserName = "timofeysolomko"
        info.ownerGroupName = "staff"
        info.ownerID = 501
        info.groupID = 20
        info.permissions = Permissions(rawValue: 420)
        let date = Date()
        info.modificationTime = date
        info.creationTime = date
        info.accessTime = date
        info.comment = "comment"

        let data = "Hello, World!\n".data(using: .utf8)!
        let entry = TarEntry(info: info, data: data)
        let containerData = try TarContainer.create(from: [entry])
        let newEntries = try TarContainer.open(container: containerData)

        XCTAssertEqual(newEntries.count, 1)
        XCTAssertEqual(newEntries[0].info.name, "file.txt")
        XCTAssertEqual(newEntries[0].info.type, .regular)
        XCTAssertEqual(newEntries[0].info.size, 14)
        XCTAssertEqual(newEntries[0].info.ownerUserName, "timofeysolomko")
        XCTAssertEqual(newEntries[0].info.ownerGroupName, "staff")
        XCTAssertEqual(newEntries[0].info.ownerID, 501)
        XCTAssertEqual(newEntries[0].info.groupID, 20)
        XCTAssertEqual(newEntries[0].info.permissions, Permissions(rawValue: 420))
        XCTAssertEqual(newEntries[0].info.comment, "comment")
        XCTAssertEqual(newEntries[0].data, data)
    }

    func test2() throws {
        let dict = [
            "SWCompression/Tests/TAR": "value",
            "key": "valuevaluevaluevaluevaluevaluevaluevaluevaluevaluevaluevaluevaluevaluevaluevaluevaluevalue22"
        ]

        var info = TarEntryInfo(name: "symbolic-link", type: .symbolicLink)
        info.accessTime = Date(timeIntervalSince1970: 1)
        info.creationTime = Date(timeIntervalSince1970: 2)
        info.modificationTime = Date(timeIntervalSince1970: 0)
        info.permissions = Permissions(rawValue: 420)
        info.permissions?.insert(.executeOwner)
        info.ownerID = 250
        info.groupID = 250
        info.ownerUserName = "testUserName"
        info.ownerGroupName = "testGroupName"
        info.deviceMajorNumber = 1
        info.deviceMinorNumber = 2
        info.charset = "UTF-8"
        info.comment = "some comment..."
        info.linkName = "file"
        info.unknownExtendedHeaderRecords = dict

        let containerData = try TarContainer.create(from: [TarEntry(info: info, data: Data())])
        let newInfo = try TarContainer.open(container: containerData)[0].info

        XCTAssertEqual(newInfo.name, "symbolic-link")
        XCTAssertEqual(newInfo.type, .symbolicLink)
        XCTAssertEqual(newInfo.permissions?.rawValue, 484)
        XCTAssertEqual(newInfo.ownerID, 250)
        XCTAssertEqual(newInfo.groupID, 250)
        XCTAssertEqual(newInfo.size, 0)
        XCTAssertEqual(newInfo.modificationTime?.timeIntervalSince1970, 0)
        XCTAssertEqual(newInfo.linkName, "file")
        XCTAssertEqual(newInfo.ownerUserName, "testUserName")
        XCTAssertEqual(newInfo.ownerGroupName, "testGroupName")
        XCTAssertEqual(newInfo.deviceMajorNumber, 1)
        XCTAssertEqual(newInfo.deviceMinorNumber, 2)
        XCTAssertEqual(newInfo.accessTime?.timeIntervalSince1970, 1)
        XCTAssertEqual(newInfo.creationTime?.timeIntervalSince1970, 2)
        XCTAssertEqual(newInfo.charset, "UTF-8")
        XCTAssertEqual(newInfo.comment, "some comment...")
        XCTAssertEqual(newInfo.unknownExtendedHeaderRecords, dict)
    }

    func testLongName() throws {
        var info = TarEntryInfo(name: "", type: .regular)
        info.name = "path/to/"
        info.name.append(String(repeating: "readme/", count: 15))
        info.name.append("readme.txt")

        let containerData = try TarContainer.create(from: [TarEntry(info: info, data: Data())])
        let newInfo = try TarContainer.open(container: containerData)[0].info

        // This name should fit into ustar format using "prefix" field
        XCTAssertEqual(newInfo.name, info.name)
    }

    func testVeryLongName() throws {
        var info = TarEntryInfo(name: "", type: .regular)
        info.name = "path/to/"
        info.name.append(String(repeating: "readme/", count: 25))
        info.name.append("readme.txt")

        let containerData = try TarContainer.create(from: [TarEntry(info: info, data: Data())])
        let newInfo = try TarContainer.open(container: containerData)[0].info

        XCTAssertEqual(newInfo.name, info.name)
    }

    func testLongDirectoryName() throws {
        // Tests what happens to the filename's trailing slash when "prefix" field is used.
        var info = TarEntryInfo(name: "", type: .regular)
        info.name = "path/to/"
        info.name.append(String(repeating: "readme/", count: 15))

        let containerData = try TarContainer.create(from: [TarEntry(info: info, data: Data())])
        let newInfo = try TarContainer.open(container: containerData)[0].info

        XCTAssertEqual(newInfo.name, info.name)
    }

    func testUnicode() throws {
        let date = Date(timeIntervalSince1970: 1300000)
        var info = TarEntryInfo(name: "ссылка", type: .symbolicLink)
        info.accessTime = date
        info.creationTime = date
        info.modificationTime = date
        info.permissions = Permissions(rawValue: 420)
        info.ownerID = 501
        info.groupID = 20
        info.ownerUserName = "timofeysolomko"
        info.ownerGroupName = "staff"
        info.deviceMajorNumber = 1
        info.deviceMinorNumber = 2
        info.comment = "комментарий"
        info.linkName = "путь/к/файлу"

        let containerData = try TarContainer.create(from: [TarEntry(info: info, data: Data())])
        XCTAssertEqual(try TarContainer.formatOf(container: containerData), .pax)
        let newInfo = try TarContainer.open(container: containerData)[0].info

        XCTAssertEqual(newInfo.name, "ссылка")
        XCTAssertEqual(newInfo.type, .symbolicLink)
        XCTAssertEqual(newInfo.permissions?.rawValue, 420)
        XCTAssertEqual(newInfo.ownerID, 501)
        XCTAssertEqual(newInfo.groupID, 20)
        XCTAssertEqual(newInfo.size, 0)
        XCTAssertEqual(newInfo.modificationTime?.timeIntervalSince1970, 1300000)
        XCTAssertEqual(newInfo.linkName, "путь/к/файлу")
        XCTAssertEqual(newInfo.ownerUserName, "timofeysolomko")
        XCTAssertEqual(newInfo.ownerGroupName, "staff")
        XCTAssertEqual(newInfo.accessTime?.timeIntervalSince1970, 1300000)
        XCTAssertEqual(newInfo.creationTime?.timeIntervalSince1970, 1300000)
        XCTAssertEqual(newInfo.comment, "комментарий")
    }

    func testUstar() throws {
        // This set of settings should result in the container which uses only ustar TAR format features.
        let date = Date(timeIntervalSince1970: 1300000)
        var info = TarEntryInfo(name: "file.txt", type: .regular)
        info.permissions = Permissions(rawValue: 420)
        info.ownerID = 501
        info.groupID = 20
        info.modificationTime = date

        let containerData = try TarContainer.create(from: [TarEntry(info: info, data: Data())])
        XCTAssertEqual(try TarContainer.formatOf(container: containerData), .ustar)
        let newInfo = try TarContainer.open(container: containerData)[0].info

        XCTAssertEqual(newInfo.name, "file.txt")
        XCTAssertEqual(newInfo.type, .regular)
        XCTAssertEqual(newInfo.permissions?.rawValue, 420)
        XCTAssertEqual(newInfo.ownerID, 501)
        XCTAssertEqual(newInfo.groupID, 20)
        XCTAssertEqual(newInfo.size, 0)
        XCTAssertEqual(newInfo.modificationTime?.timeIntervalSince1970, 1300000)
        XCTAssertEqual(newInfo.linkName, "")
        XCTAssertEqual(newInfo.ownerUserName, "")
        XCTAssertEqual(newInfo.ownerGroupName, "")
        XCTAssertNil(newInfo.accessTime)
        XCTAssertNil(newInfo.creationTime)
        XCTAssertNil(newInfo.comment)
    }

    func testNegativeMtime() throws {
        let date = Date(timeIntervalSince1970: -1300000)
        var info = TarEntryInfo(name: "file.txt", type: .regular)
        info.modificationTime = date

        let containerData = try TarContainer.create(from: [TarEntry(info: info, data: Data())])
        XCTAssertEqual(try TarContainer.formatOf(container: containerData), .pax)
        let newInfo = try TarContainer.open(container: containerData)[0].info

        XCTAssertEqual(newInfo.name, "file.txt")
        XCTAssertEqual(newInfo.type, .regular)
        XCTAssertEqual(newInfo.size, 0)
        XCTAssertEqual(newInfo.modificationTime?.timeIntervalSince1970, -1300000)
        XCTAssertEqual(newInfo.linkName, "")
        XCTAssertEqual(newInfo.ownerUserName, "")
        XCTAssertEqual(newInfo.ownerGroupName, "")
        XCTAssertNil(newInfo.permissions)
        XCTAssertNil(newInfo.ownerID)
        XCTAssertNil(newInfo.groupID)
        XCTAssertNil(newInfo.accessTime)
        XCTAssertNil(newInfo.creationTime)
        XCTAssertNil(newInfo.comment)
    }

    func testBigUid() throws {
        let uid = (1 << 32) - 1
        var info = TarEntryInfo(name: "file.txt", type: .regular)
        info.ownerID = uid

        let containerData = try TarContainer.create(from: [TarEntry(info: info, data: Data())])
        XCTAssertEqual(try TarContainer.formatOf(container: containerData), .pax)
        let newInfo = try TarContainer.open(container: containerData)[0].info

        XCTAssertEqual(newInfo.name, "file.txt")
        XCTAssertEqual(newInfo.type, .regular)
        XCTAssertEqual(newInfo.size, 0)
        XCTAssertEqual(newInfo.ownerID, uid)
        XCTAssertEqual(newInfo.linkName, "")
        XCTAssertEqual(newInfo.ownerUserName, "")
        XCTAssertEqual(newInfo.ownerGroupName, "")
        XCTAssertNil(newInfo.permissions)
        XCTAssertNil(newInfo.groupID)
        XCTAssertNil(newInfo.accessTime)
        XCTAssertNil(newInfo.creationTime)
        XCTAssertNil(newInfo.modificationTime)
        XCTAssertNil(newInfo.comment)
    }

}
