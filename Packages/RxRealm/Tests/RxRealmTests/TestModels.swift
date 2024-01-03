//
//  TestModels.swift
//  RxRealm
//
//  Created by Marin Todorov on 4/30/16.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import Foundation
import RealmSwift
import RxRealm

func realmInMemory(_ name: String = UUID().uuidString) -> Realm {
  var conf = Realm.Configuration()
  conf.inMemoryIdentifier = name
  return try! Realm(configuration: conf)
}

func stringifyChanges<E>(_ arg: (AnyRealmCollection<E>, RealmChangeset?)) -> String {
  let (result, changes) = arg
  if let changes = changes {
    return "count:\(result.count) inserted:\(changes.inserted) deleted:\(changes.deleted) updated:\(changes.updated)"
  } else {
    return "count:\(result.count)"
  }
}

// MARK: Message
class Message: Object {
  @objc dynamic var text = ""

  let recipients = List<User>()
  let mentions = LinkingObjects(fromType: User.self, property: "lastMessage")

  convenience init(_ text: String) {
    self.init()
    self.text = text
  }
}

// MARK: User
class User: Object {
  @objc dynamic var name = ""
  @objc dynamic var lastMessage: Message?

  convenience init(_ name: String) {
    self.init()
    self.name = name
  }
}

// MARK: UniqueObject
class UniqueObject: Object {
  @objc dynamic var id = 0
  @objc dynamic var name = ""

  convenience init(_ id: Int) {
    self.init()
    self.id = id
  }

  override class func primaryKey() -> String? {
    return "id"
  }
}
