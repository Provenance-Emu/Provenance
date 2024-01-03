//
//  RxRealmCollectionsTests.swift
//  RxRealm
//
//  Created by Marin Todorov on 4/30/16.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import XCTest

import RealmSwift
import RxRealm
import RxSwift

class RxRealmResultsTests: XCTestCase {
  let allTests = [
    "testResultsType": testResultsType,
    "testResultsTypeChangeset": testResultsTypeChangeset,
    "testResultsEmitsCollectionSynchronously": testResultsEmitsCollectionSynchronously,
    "testResultsEmitsChangesetSynchronously": testResultsEmitsChangesetSynchronously,
    "testResultsEmitsCollectionAsynchronously": testResultsEmitsCollectionAsynchronously,
    "testResultsEmitsChangesetAsynchronously": testResultsEmitsChangesetAsynchronously
  ]
  func testResultsType() {
    let realm = realmInMemory(#function)
    let messages = Observable.collection(from: realm.objects(Message.self))
      .map { Array($0.map { $0.text }) }

    XCTAssertEqual(try! messages.toBlocking().first()!, [])

    DispatchQueue.main.async {
      try! realm.write {
        realm.add(Message("first"))
      }
    }

    XCTAssertEqual(try! messages.skip(1).toBlocking().first()!, ["first"])

    DispatchQueue.main.async {
      try! realm.write {
        realm.delete(realm.objects(Message.self).first!)
      }
    }

    XCTAssertEqual(try! messages.skip(1).toBlocking().first()!, [])
  }

  func testResultsTypeChangeset() {
    let realm = realmInMemory(#function)
    let messages = Observable.changeset(from: realm.objects(Message.self))
      .map(stringifyChanges)

    XCTAssertEqual(try! messages.toBlocking().first()!, "count:0")

    DispatchQueue.main.async {
      try! realm.write {
        realm.add(Message("first"))
      }
    }

    XCTAssertEqual(try! messages.skip(1).toBlocking().first()!, "count:1 inserted:[0] deleted:[] updated:[]")

    DispatchQueue.global(qos: .background).async {
      let realm = realmInMemory(#function)
      try! realm.write {
        realm.delete(realm.objects(Message.self).first!)
      }
    }

    XCTAssertEqual(try! messages.skip(1).toBlocking().first()!, "count:0 inserted:[] deleted:[0] updated:[]")
  }

  func testResultsEmitsCollectionSynchronously() {
    let realm = realmInMemory(#function)
    let messages = Observable.collection(from: realm.objects(Message.self), synchronousStart: true)
    var result = false

    // synchornously set to true
    _ = messages.subscribe(onNext: { _ in
      result = true
    })

    XCTAssertEqual(result, true)
  }

  func testResultsEmitsChangesetSynchronously() {
    let realm = realmInMemory(#function)
    let messages = Observable.changeset(from: realm.objects(Message.self), synchronousStart: true)
    var result = false

    // synchornously set to true
    _ = messages.subscribe(onNext: { _ in
      result = true
    })

    XCTAssertEqual(result, true)
  }

  func testResultsEmitsCollectionAsynchronously() {
    let realm = realmInMemory(#function)
    let messages = Observable.collection(from: realm.objects(Message.self), synchronousStart: false)
    var result = false

    // synchornously set to true
    _ = messages.subscribe(onNext: { _ in
      result = true
    })

    XCTAssertEqual(result, false)
  }

  func testResultsEmitsChangesetAsynchronously() {
    let realm = realmInMemory(#function)
    let messages = Observable.changeset(from: realm.objects(Message.self), synchronousStart: false)
    var result = false

    // synchornously set to true
    _ = messages.subscribe(onNext: { _ in
      result = true
    })

    XCTAssertEqual(result, false)
  }
}
