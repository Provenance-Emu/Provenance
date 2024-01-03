//
//  RxRealm extensions
//
//  Copyright (c) 2016 RxSwiftCommunity. All rights reserved.
//

import XCTest

import RealmSwift
import RxRealm
import RxSwift

// TODO: remove
func delay(_ delay: Double, closure: @escaping () -> Void) {
  DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(delay * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: closure)
}

func delayInBackground(_ delay: Double, closure: @escaping () -> Void) {
  DispatchQueue.global(qos: DispatchQoS.QoSClass.background).asyncAfter(deadline: DispatchTime.now() + Double(Int64(delay * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: closure)
}

func addMessage(_ realm: Realm, text: String) {
  try! realm.write {
    realm.add(Message(text))
  }
}

class RxRealm_Tests: XCTestCase {
  let allTests = [
    "testEmittedResultsValues": testEmittedResultsValues,
    "testEmittedArrayValues": testEmittedArrayValues,
    "testEmittedChangeset": testEmittedChangeset,
    "testEmittedArrayChangeset": testEmittedArrayChangeset
  ]
  func testEmittedResultsValues() {
    let realm = realmInMemory(#function)
    let messages = Observable.collection(from: realm.objects(Message.self))
      .skip(1)
      .map { Array($0.map { $0.text }) }

    DispatchQueue.main.async {
      addMessage(realm, text: "first(Results)")
    }
    XCTAssertEqual(try! messages.toBlocking().first()!, ["first(Results)"])

    DispatchQueue.main.async {
      addMessage(realm, text: "second(Results)")
    }
    XCTAssertEqual(try! messages.toBlocking().first()!, ["first(Results)", "second(Results)"])
  }

  func testEmittedArrayValues() {
    let realm = realmInMemory(#function)
    let messages = Observable.array(from: realm.objects(Message.self))
      .skip(1)
      .map { $0.map { $0.text } }

    DispatchQueue.main.async {
      addMessage(realm, text: "first(Results)")
    }
    XCTAssertEqual(try! messages.toBlocking().first()!, ["first(Results)"])

    DispatchQueue.main.async {
      addMessage(realm, text: "second(Results)")
    }
    XCTAssertEqual(try! messages.toBlocking().first()!, ["first(Results)", "second(Results)"])
  }

  func testEmittedChangeset() {
    let realm = realmInMemory(#function)

    // initial data
    addMessage(realm, text: "first(Changeset)")

    let messagesInitial = Observable.changeset(from: realm.objects(Message.self).sorted(byKeyPath: "text"))
      .map(stringifyChanges)

    XCTAssertEqual(try! messagesInitial.toBlocking().first()!, "count:1")

    let messages = messagesInitial.skip(1)

    // insert
    DispatchQueue.main.async {
      addMessage(realm, text: "second(Changeset)")
    }
    XCTAssertEqual(try! messages.toBlocking().first()!, "count:2 inserted:[1] deleted:[] updated:[]")

    // update
    DispatchQueue.main.async {
      try! realm.write {
        realm.objects(Message.self).filter("text='second(Changeset)'").first!.text = "third(Changeset)"
      }
    }
    XCTAssertEqual(try! messages.toBlocking().first()!, "count:2 inserted:[] deleted:[] updated:[1]")

    // coalesced + delete
    DispatchQueue.main.async {
      try! realm.write {
        realm.add(Message("zzzzz(Changeset)"))
        realm.delete(realm.objects(Message.self).filter("text='first(Changeset)'").first!)
      }
    }
    XCTAssertEqual(try! messages.toBlocking().first()!, "count:2 inserted:[1] deleted:[0] updated:[]")
  }

  func testEmittedArrayChangeset() {
    let realm = realmInMemory(#function)

    // initial data
    addMessage(realm, text: "first(Changeset)")

    let messagesInitial = Observable.arrayWithChangeset(from: realm.objects(Message.self).sorted(byKeyPath: "text"))
      .map { (arg) -> String in
        let (result, changes) = arg
        if let changes = changes {
          return "count:\(result.count) inserted:\(changes.inserted) deleted:\(changes.deleted) updated:\(changes.updated)"
        } else {
          return "count:\(result.count)"
        }
      }

    XCTAssertEqual(try! messagesInitial.toBlocking().first()!, "count:1")

    let messages = messagesInitial.skip(1)

    // insert
    DispatchQueue.main.async {
      addMessage(realm, text: "second(Changeset)")
    }
    XCTAssertEqual(try! messages.toBlocking().first()!, "count:2 inserted:[1] deleted:[] updated:[]")

    // update
    DispatchQueue.main.async {
      try! realm.write {
        realm.objects(Message.self).filter("text='second(Changeset)'").first!.text = "third(Changeset)"
      }
    }
    XCTAssertEqual(try! messages.toBlocking().first()!, "count:2 inserted:[] deleted:[] updated:[1]")

    // coalesced + delete
    DispatchQueue.main.async {
      try! realm.write {
        realm.add(Message("zzzzz(Changeset)"))
        realm.delete(realm.objects(Message.self).filter("text='first(Changeset)'").first!)
      }
    }
    XCTAssertEqual(try! messages.toBlocking().first()!, "count:2 inserted:[1] deleted:[0] updated:[]")
  }
}
