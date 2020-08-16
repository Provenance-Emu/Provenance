//
//  ViewController.swift
//  RxReachability
//
//  Created by ivanbruel on 03/22/2017.
//  Copyright (c) RxSwiftCommunity. All rights reserved.
//

import UIKit
import Reachability
import RxSwift
import RxCocoa
import RxReachability

class ViewController: UIViewController {

  @IBOutlet private weak var label: UILabel!

  let reachability = try! Reachability()
  let disposeBag = DisposeBag()

  override func viewDidLoad() {
    super.viewDidLoad()

    reachability.rx.isReachable
      .map { "Is reachable: \($0)" }
      .bind(to: label.rx.text)
      .disposed(by: disposeBag)
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    try? reachability.startNotifier()
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    reachability.stopNotifier()
  }
}
