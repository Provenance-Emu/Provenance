//
//  RxRealmObjectTests.swift
//  RxRealm
//
//  Created by Marin Todorov on 10/31/16.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import XCTest

import RealmSwift
import RxRealm
import RxSwift

class RxRealmObjectTests: XCTestCase {
  let allTests = [
    "testObjectChangeNotifications": testObjectChangeNotifications,
    "testObjectEmitsInitialChange": testObjectEmitsInitialChange,
    "testObjectDoesntEmitInitialValue": testObjectDoesntEmitInitialValue,
    "testObjectPropertyChangeNotifications": testObjectPropertyChangeNotifications,
    "testObjectChangeNotificationsForProperties": testObjectChangeNotificationsForProperties
  ]
  func testObjectChangeNotifications() {
    let realm = realmInMemory(#function)

    // create object
    let idValue = 1024
    let obj = UniqueObject(idValue)
    try! realm.write {
      realm.add(obj)
    }

    let objectNotifications = Observable<UniqueObject>.from(object: obj)
      .map { $0.name }

    XCTAssertEqual(try! objectNotifications.toBlocking().first()!, "")

    DispatchQueue.main.async {
      try! realm.write {
        obj.name = "test1"
      }
    }
    XCTAssertEqual(try! objectNotifications.skip(1).toBlocking().first()!, "test1")

    DispatchQueue.global(qos: .background).async {
      let realm = realmInMemory(#function)
      try! realm.write {
        realm.objects(UniqueObject.self).filter("id == %@", idValue).first!.name = "test2"
      }
    }

    XCTAssertEqual(try! objectNotifications.skip(1).toBlocking().first()!, "test2")

    // delete the object to trigger an error
    DispatchQueue.main.async {
      try! realm.write {
        realm.delete(obj)
      }
    }

    XCTAssertThrowsError(try objectNotifications.skip(1).toBlocking().first()!) { error in
      XCTAssertEqual(error as! RxRealmError, RxRealmError.objectDeleted)
    }
  }

  func testObjectEmitsInitialChange() {
    let realm = realmInMemory(#function)

    let obj = UniqueObject(1024)
    try! realm.write {
      realm.add(obj)
    }

    var result = false

    // emits upon subscription
    _ = Observable.from(object: obj, emitInitialValue: true)
      .subscribe(onNext: { _ in
        result = true
      })

    XCTAssertEqual(result, true)
  }

  func testObjectDoesntEmitInitialValue() {
    let realm = realmInMemory(#function)

    let obj = UniqueObject(1024)
    try! realm.write {
      realm.add(obj)
    }

    var result = false

    // doesn't emit upon subscription
    _ = Observable.from(object: obj, emitInitialValue: false)
      .subscribe(onNext: { _ in
        result = true
      })

    XCTAssertEqual(result, false)
  }

  func testObjectPropertyChangeNotifications() {
    let realm = realmInMemory(#function)

    let obj = UniqueObject(1024)
    try! realm.write {
      realm.add(obj)
    }

    let objectNotifications = Observable.propertyChanges(object: obj)
      .map { "\($0.name):\($0.newValue!)" }

    DispatchQueue.main.async {
      try! realm.write {
        obj.name = "test1"
      }
    }
    XCTAssertEqual(try! objectNotifications.toBlocking().first()!, "name:test1")

    DispatchQueue.global(qos: .background).async {
      let realm = realmInMemory(#function)
      try! realm.write {
        realm.objects(UniqueObject.self).first!.name = "test2"
      }
    }
    XCTAssertEqual(try! objectNotifications.toBlocking().first()!, "name:test2")

    // delete the object to trigger an error
    DispatchQueue.main.async {
      try! realm.write {
        realm.delete(obj)
      }
    }
    XCTAssertThrowsError(try objectNotifications.toBlocking().first()!) { error in
      XCTAssertEqual(error as! RxRealmError, RxRealmError.objectDeleted)
    }
  }

  func testObjectChangeNotificationsForProperties() {
    let realm = realmInMemory(#function)

    let obj = UniqueObject(1024)
    try! realm.write {
      realm.add(obj)
    }

    let objectNotifications = Observable.from(object: obj, emitInitialValue: false, properties: ["name"])
      .map { "\($0.name)" }

    DispatchQueue.main.async {
      try! realm.write {
        obj.name = "test1"
      }
    }
    XCTAssertEqual(try! objectNotifications.toBlocking().first()!, "test1")

    DispatchQueue.global(qos: .background).async {
      let realm = realmInMemory(#function)
      try! realm.write {
        realm.objects(UniqueObject.self).first!.name = "test2"
      }
    }
    XCTAssertEqual(try! objectNotifications.toBlocking().first()!, "test2")

    // delete the object to trigger an error
    DispatchQueue.main.async {
      try! realm.write {
        realm.delete(obj)
      }
    }
    XCTAssertThrowsError(try objectNotifications.toBlocking().first()!) { error in
      XCTAssertEqual(error as! RxRealmError, RxRealmError.objectDeleted)
    }
  }
}
