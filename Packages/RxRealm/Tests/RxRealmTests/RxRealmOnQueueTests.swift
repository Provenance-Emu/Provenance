//
//  RxRealmOnQueueTests.swift
//  RxRealm_Tests
//
//  Created by Anton Nazarov on 18.05.2020.
//  Copyright © 2020 CocoaPods. All rights reserved.
//

import RealmSwift
import RxSwift
import XCTest

final class RxRealmOnQueueTests: XCTestCase {
  let allTests = [
    "testCollectionOnQueue": testCollectionOnQueue,
    "testArrayOnQueue": testArrayOnQueue,
    "testChangesetOnQueue": testChangesetOnQueue
  ]
  func testCollectionOnQueue() {
    verifyObservableEmitOnBackground {
      Observable.collection(from: $0, synchronousStart: false, on: DispatchQueue(label: #function))
    }
  }

  func testArrayOnQueue() {
    verifyObservableEmitOnBackground {
      Observable.array(from: $0, synchronousStart: false, on: DispatchQueue(label: #function))
    }
  }

  func testChangesetOnQueue() {
    verifyObservableEmitOnBackground {
      Observable.changeset(from: $0, synchronousStart: false, on: DispatchQueue(label: #function))
    }
  }

  private func verifyObservableEmitOnBackground<Element>(factory: (Results<UniqueObject>) -> Observable<Element>) {
    let realm = realmInMemory()
    DispatchQueue.main.async {
      try! realm.write {
        realm.add(UniqueObject(1))
      }
    }
    let dispatchedOnMainTread = try! factory(realm.objects(UniqueObject.self))
      .map { _ in Thread.isMainThread }
      .toBlocking(timeout: 2)
      .first()
    XCTAssertFalse(dispatchedOnMainTread!)
  }
}
