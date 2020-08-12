//
//  ObservableType+Reachability.swift
//  Pods
//
//  Created by Ivan Bruel on 22/03/2017.
//  Copyright (c) RxSwiftCommunity. All rights reserved.
//
//

import Foundation
import Reachability
import RxCocoa
import RxSwift

public extension ObservableType {

    func retryOnConnect(timeout: DispatchTimeInterval) -> Observable<Element> {
    return retryWhen { _ in
      return Reachability.rx.isConnected
        .timeout(timeout, scheduler: MainScheduler.asyncInstance)
    }
  }

  func retryOnConnect(
    timeout: DispatchTimeInterval,
    predicate: @escaping (Swift.Error) -> Bool
  ) -> Observable<Element> {
    return retryWhen {
      return $0
        .filter(predicate)
        .flatMap { _ in
          Reachability
            .rx
            .isConnected
            .timeout(
              timeout,
              scheduler: MainScheduler.asyncInstance
          )
        }
    }
  }

  func retryLatestOnConnect(
    timeout: DispatchTimeInterval,
    predicate: @escaping (Swift.Error) -> Bool
    ) -> Observable<Element> {
    return retryWhen {
      return $0
        .filter(predicate)
        .flatMapLatest { _ in
          Reachability
            .rx
            .isConnected
            .timeout(
              timeout,
              scheduler: MainScheduler.asyncInstance
            )
        }
    }
  }

}
