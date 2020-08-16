//
//  Reachability+Rx.swift
//
//  Created by Ivan Bruel on 22/03/2017.
//  Copyright (c) RxSwiftCommunity. All rights reserved.
//

import Foundation
import Reachability
import RxCocoa
import RxSwift

extension Reachability: ReactiveCompatible { }

public extension Reactive where Base: Reachability {

    static var reachabilityChanged: Observable<Reachability> {
    return NotificationCenter.default.rx.notification(Notification.Name.reachabilityChanged)
      .flatMap { notification -> Observable<Reachability> in
        guard let reachability = notification.object as? Reachability else {
          return .empty()
        }
        return .just(reachability)
    }
  }

    static var status: Observable<Reachability.Connection> {
    return reachabilityChanged
      .map { $0.connection }
  }

    static var isReachable: Observable<Bool> {
    return reachabilityChanged
        .map { $0.connection != .unavailable }
  }

    static var isConnected: Observable<Void> {
    return isReachable
      .filter { $0 }
      .map { _ in Void() }
  }

    static var isDisconnected: Observable<Void> {
    return isReachable
      .filter { !$0 }
      .map { _ in Void() }
  }
}

public extension Reactive where Base: Reachability {

    var reachabilityChanged: Observable<Reachability> {
    return NotificationCenter.default.rx.notification(Notification.Name.reachabilityChanged, object: base)
      .flatMap { notification -> Observable<Reachability> in
        guard let reachability = notification.object as? Reachability else {
          return .empty()
        }
        return .just(reachability)
    }
  }

    var status: Observable<Reachability.Connection> {
    return reachabilityChanged
      .map { $0.connection }
  }

    var isReachable: Observable<Bool> {
    return reachabilityChanged
        .map { $0.connection != .unavailable }
  }

    var isConnected: Observable<Void> {
    return isReachable
      .filter { $0 }
      .map { _ in Void() }
  }

    var isDisconnected: Observable<Void> {
    return isReachable
      .filter { !$0 }
      .map { _ in Void() }
  }
}
