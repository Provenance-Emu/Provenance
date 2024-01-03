//
//  RxRealmLinkingObjectsTests.swift
//  RxRealm
//
//  Created by Marin Todorov on 5/1/16.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import XCTest

import RealmSwift
import RxRealm
import RxSwift

class RxRealmLinkingObjectsTests: XCTestCase {
  let allTests = [
    "testLinkingObjectsType": testLinkingObjectsType,
    "testLinkingObjectsTypeChangeset": testLinkingObjectsTypeChangeset
  ]

  func testLinkingObjectsType() {
    let realm = realmInMemory(#function)

    let message = Message("first")
    try! realm.write {
      realm.add(message)
    }

    let users = Observable.collection(from: message.mentions)
      .map { $0.count }

    XCTAssertEqual(try! users.toBlocking().first()!, 0)

    let user1 = User("user1")
    user1.lastMessage = message

    DispatchQueue.main.async {
      try! realm.write {
        realm.add(user1)
      }
    }

    XCTAssertEqual(try! users.skip(1).toBlocking().first()!, 1)

    DispatchQueue.global(qos: .background).async {
      let realm = realmInMemory(#function)
      let user1 = realm.objects(User.self).first!
      try! realm.write {
        realm.delete(user1)
      }
    }

    XCTAssertEqual(try! users.skip(1).toBlocking().first()!, 0)
  }

  func testLinkingObjectsTypeChangeset() {
    let realm = realmInMemory(#function)

    let message = Message("first")
    try! realm.write {
      realm.add(message)
    }

    let users = Observable.changeset(from: message.mentions)
      .map(stringifyChanges)

    XCTAssertEqual(try! users.toBlocking().first()!, "count:0")

    let user1 = User("user1")
    user1.lastMessage = message

    DispatchQueue.main.async {
      try! realm.write {
        realm.add(user1)
      }
    }

    XCTAssertEqual(try! users.skip(1).toBlocking().first()!, "count:1 inserted:[0] deleted:[] updated:[]")

    DispatchQueue.global(qos: .background).async {
      let realm = realmInMemory(#function)
      let user1 = realm.objects(User.self).first!
      try! realm.write {
        realm.delete(user1)
      }
    }

    XCTAssertEqual(try! users.skip(1).toBlocking().first()!, "count:0 inserted:[] deleted:[0] updated:[]")
  }
}
