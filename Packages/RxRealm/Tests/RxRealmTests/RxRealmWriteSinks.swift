//
//  RxRealmWriteSinks.swift
//  RxRealm
//
//  Created by Marin Todorov on 6/4/16.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import RealmSwift
import RxBlocking
import RxCocoa
import RxRealm
import RxSwift
import XCTest

enum WriteError: Error {
  case def
}

class RxRealmWriteSinks: XCTestCase {
  let allTests = [
    "testRxAddObjectWithSuccess": testRxAddObjectWithSuccess,
    "testRxAddObjectWithError": testRxAddObjectWithError,
    "testRxAddSequenceWithSuccess": testRxAddSequenceWithSuccess,
    "testRxAddSequenceWithError": testRxAddSequenceWithError,
    "testRxAddUpdateObjectsWithSucess": testRxAddUpdateObjectsWithSucess,
    "testRxDeleteItem": testRxDeleteItem,
    "testRxDeleteItemWithError": testRxDeleteItemWithError,
    "testRxDeleteItemsWithSuccess": testRxDeleteItemsWithSuccess,
    "testRxDeleteItemsWithError": testRxDeleteItemsWithError,
    "testRxAddObjectsFromDifferentThreads": testRxAddObjectsFromDifferentThreads
  ]
  func testRxAddObjectWithSuccess() {
    let realm = realmInMemory(#function)
    let items = Observable.array(from: realm.objects(Message.self))
      .map { $0.map { $0.text } }

    // show all speakers
    DispatchQueue.main.async {
      _ = Observable.just(Message("1")).subscribe(realm.rx.add())
    }

    let result = try! items.skip(1).toBlocking(timeout: 1).first()!
    XCTAssertEqual(result[0], "1")
  }

  func testRxAddObjectWithError() {
    var conf = Realm.Configuration()
    conf.fileURL = URL(string: "/asdasdasdsad")!

    let recordedError = BehaviorRelay<Error?>(value: nil)

    DispatchQueue.main.async {
      _ = Observable.just(Message("0"))
        .subscribe(Realm.rx.add(configuration: conf, update: .all, onError: { _, error in
          recordedError.accept(error)
        }))
    }

    let error = try! recordedError.asObservable().skip(1).toBlocking(timeout: 1).first()!
    XCTAssertNotNil(error)
    XCTAssertEqual((error! as NSError).code, 3)
  }

  func testRxAddSequenceWithSuccess() {
    let realm = realmInMemory(#function)
    let items = Observable.array(from: realm.objects(Message.self))
      .map { $0.map { $0.text } }

    // show all speakers
    DispatchQueue.main.async {
      _ = Observable.just([Message("1"), Message("2")]).subscribe(realm.rx.add())
    }

    let result = try! items.skip(1).toBlocking(timeout: 1).first()!
    XCTAssertEqual(result[0], "1")
    XCTAssertEqual(result[1], "2")
  }

  func testRxAddSequenceWithError() {
    var conf = Realm.Configuration()
    conf.fileURL = URL(string: "/asdasdasdsad")!

    let recordedError = BehaviorRelay<Error?>(value: nil)

    // show all speakers
    DispatchQueue.main.async {
      _ = Observable.from([Message("1"), Message("2")])
        .subscribe(Realm.rx.add(configuration: conf, update: .all, onError: { _, error in
          recordedError.accept(error)
        }))
    }

    let error = try! recordedError.asObservable().skip(1).toBlocking(timeout: 1).first()!
    XCTAssertNotNil(error)
    XCTAssertEqual((error! as NSError).code, 3)
  }

  func testRxAddUpdateObjectsWithSucess() {
    let realm = realmInMemory(#function)
    let items = Observable.array(from: realm.objects(UniqueObject.self).sorted(byKeyPath: "id"))
      .map { $0.map { $0.id } }

    // show all speakers
    DispatchQueue.main.async {
      _ = Observable.just([UniqueObject(1), UniqueObject(2)]).subscribe(realm.rx.add())
      _ = Observable.just([UniqueObject(1), UniqueObject(3)]).subscribe(realm.rx.add(update: .all))
    }

    let result = try! items.skip(1).take(2).toBlocking(timeout: 1).toArray()
    XCTAssertEqual(result[0], [1, 2])
    XCTAssertEqual(result[1], [1, 2, 3])
  }

  func testRxDeleteItem() {
    let realm = realmInMemory(#function)
    let items = Observable.array(from: realm.objects(UniqueObject.self))
      .map { $0.map { $0.id } }

    let object1 = UniqueObject(1)
    let object2 = UniqueObject(2)
    try! realm.write {
      realm.add([object1, object2])
    }

    // show all speakers
    DispatchQueue.main.async {
      _ = Observable.just(object1).subscribe(realm.rx.delete())
      _ = Observable.just(object2).subscribe(Realm.rx.delete())
    }

    let result = try! items.take(3).toBlocking(timeout: 1).toArray()
    XCTAssertEqual(result[0], [1, 2])
    XCTAssertEqual(result[1], [2])
    XCTAssertEqual(result[2], [])
  }

  func testRxDeleteItemWithError() {
    let object1 = UniqueObject(1)
    let recordedError = BehaviorRelay<Error?>(value: nil)

    DispatchQueue.main.async {
      _ = Observable.just(object1)
        .subscribe(Realm.rx.delete(onError: { _, error in
          recordedError.accept(error)
        }))
    }

    let error = try! recordedError.asObservable().skip(1).toBlocking(timeout: 1).first()!
    XCTAssertNotNil(error)
  }

  func testRxDeleteItemsWithSuccess() {
    let realm = realmInMemory(#function)
    let items = Observable.array(from: realm.objects(UniqueObject.self).sorted(byKeyPath: "id"))
      .map { $0.map { $0.id } }

    let object1 = UniqueObject(1)
    let object2 = UniqueObject(2)
    let object3 = UniqueObject(3)
    let object4 = UniqueObject(4)

    try! realm.write {
      realm.add([object1, object2, object3, object4])
    }

    // show all speakers
    DispatchQueue.main.async {
      _ = Observable.just([object1, object2]).subscribe(realm.rx.delete())
      _ = Observable.just([object3, object4]).subscribe(Realm.rx.delete())
    }

    let result = try! items.take(3).toBlocking(timeout: 1).toArray()
    XCTAssertEqual(result[0], [1, 2, 3, 4])
    XCTAssertEqual(result[1], [3, 4])
    XCTAssertEqual(result[2], [])
  }

  func testRxDeleteItemsWithError() {
    let object1 = UniqueObject(1)
    let object2 = UniqueObject(2)
    let recordedError = BehaviorRelay<Error?>(value: nil)

    DispatchQueue.main.async {
      _ = Observable.just([object1, object2])
        .subscribe(Realm.rx.delete(onError: { _, error in
          recordedError.accept(error)
        }))
    }

    let error = try! recordedError.asObservable().skip(1).toBlocking(timeout: 1).first()!
    XCTAssertNotNil(error)
  }

  func testRxAddObjectsFromDifferentThreads() {
    let realm = realmInMemory(#function)
    let conf = realm.configuration

    let items = Observable.array(from: realm.objects(UniqueObject.self).sorted(byKeyPath: "id"))
      .map { $0.map { $0.id } }

    // write on current thread
    _ = Observable.just(UniqueObject(1)).subscribe(realm.rx.add())

    // write on background thread
    DispatchQueue.global(qos: .background).async {
      let realm = try! Realm(configuration: conf)
      _ = Observable.just(UniqueObject(2))
        .subscribe(realm.rx.add())
    }

    // write on main scheduler
    DispatchQueue.global(qos: .background).async {
      _ = Observable.just(UniqueObject(3))
        .observe(on: MainScheduler.instance)
        .subscribe(Realm.rx.add(configuration: conf))
    }

    // write on bg scheduler
    DispatchQueue.main.async {
      _ = Observable.just(UniqueObject(4))
        .observe(on: ConcurrentDispatchQueueScheduler(queue: DispatchQueue.global(qos: .background)))
        .subscribe(Realm.rx.add(configuration: conf))
    }

    // subscribe on main, write in bg
    DispatchQueue.main.async {
      _ = Observable.just([UniqueObject(5), UniqueObject(6)])
        .observe(on: ConcurrentDispatchQueueScheduler(queue: DispatchQueue.global(qos: .background)))
        .subscribe(Realm.rx.add(configuration: conf))
    }

    let until = Observable.array(from: realm.objects(UniqueObject.self))
      .filter { $0.count == 6 }
      .delay(.milliseconds(100), scheduler: MainScheduler.instance)

    let result = try! items.take(until: until).toBlocking(timeout: 1).toArray()
    XCTAssertEqual(result.last!, [1, 2, 3, 4, 5, 6])
  }
}
