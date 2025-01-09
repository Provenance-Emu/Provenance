//
//  RxRealmRealmTests.swift
//  RxRealm
//
//  Created by Marin Todorov on 5/22/16.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import XCTest

import RealmSwift
import RxRealm
import RxSwift

class RxRealmRealmTests: XCTestCase {
  let allTests = [
    "testRealmDidChangeNotifications": testRealmDidChangeNotifications,
    "testRealmRefreshRequiredNotifications": testRealmRefreshRequiredNotifications
  ]
  func testRealmDidChangeNotifications() {
    let realm = realmInMemory(#function)

    let realmNotifications = Observable<(Realm, Realm.Notification)>.from(realm: realm)

    DispatchQueue.main.async {
      try! realm.write {
        realm.add(Message("first"))
      }
    }

    XCTAssertEqual(try! realmNotifications.toBlocking().first()!.1, Realm.Notification.didChange)

    DispatchQueue.global(qos: .background).async {
      let realm = realmInMemory(#function)
      try! realm.write {
        realm.add(Message("second"))
      }
    }

    XCTAssertEqual(try! realmNotifications.toBlocking().first()!.1, Realm.Notification.didChange)
  }

  func testRealmRefreshRequiredNotifications() {
    let realm = realmInMemory(#function)
    realm.autorefresh = false

    let realmNotifications = Observable<(Realm, Realm.Notification)>.from(realm: realm)

    DispatchQueue.main.async {
      try! realm.write {
        realm.add(Message("first"))
      }
    }

    // on same thread change is delivered
    XCTAssertEqual(try! realmNotifications.toBlocking().first()!.1, Realm.Notification.didChange)

    DispatchQueue.global(qos: .background).async {
      let realm = realmInMemory(#function)
      try! realm.write {
        realm.add(Message("second"))
      }
    }

    // on different thread - refresh required
    XCTAssertEqual(try! realmNotifications.toBlocking().first()!.1, Realm.Notification.refreshRequired)
  }
}
