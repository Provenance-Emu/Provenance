//
//  Example5_UIPickerView.swift
//  RxDataSources
//
//  Created by Sergey Shulga on 04/07/2017.
//  Copyright © 2017 kzaher. All rights reserved.
//

import UIKit
import RxCocoa
import RxSwift
import RxDataSources

final class ReactivePickerViewControllerExample: UIViewController {
    
    @IBOutlet weak var firstPickerView: UIPickerView!
    @IBOutlet weak var secondPickerView: UIPickerView!
    @IBOutlet weak var thirdPickerView: UIPickerView!
    
    let disposeBag = DisposeBag()

    private let stringPickerAdapter = RxPickerViewStringAdapter<[String]>(components: [],
                                                                          numberOfComponents: { _,_,_  in 1 },
                                                                          numberOfRowsInComponent: { (_, _, items, _) -> Int in
                                                                            return items.count
                                                                          },
                                                                          titleForRow: { (_, _, items, row, _) -> String? in
                                                                                return items[row]
                                                                          })
    private let attributedStringPickerAdapter = RxPickerViewAttributedStringAdapter<[String]>(components: [],
                                                                                              numberOfComponents: { _,_,_  in 1 },
                                                                                              numberOfRowsInComponent: { (_, _, items, _) -> Int in
                                                                                                return items.count
    }) { (_, _, items, row, _) -> NSAttributedString? in
        return NSAttributedString(string: items[row],
                                  attributes: [
                                    NSAttributedStringKey.foregroundColor: UIColor.purple,
                                    NSAttributedStringKey.underlineStyle: NSUnderlineStyle.styleDouble.rawValue,
                                    NSAttributedStringKey.textEffect: NSAttributedString.TextEffectStyle.letterpressStyle
            ])
    }
    private let viewPickerAdapter = RxPickerViewViewAdapter<[String]>(components: [],
                                                                      numberOfComponents: { _,_,_  in 1 },
                                                                      numberOfRowsInComponent: { (_, _, items, _) -> Int in
                                                                        return items.count
    }) { (_, _, _, row, _, view) -> UIView in
        let componentView = view ?? UIView()
        componentView.backgroundColor = row % 2 == 0 ? UIColor.red : UIColor.blue
        return componentView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        Observable.just(["One", "Two", "Tree"])
            .bind(to: firstPickerView.rx.items(adapter: stringPickerAdapter))
            .disposed(by: disposeBag)
        
        Observable.just(["One", "Two", "Tree"])
            .bind(to: secondPickerView.rx.items(adapter: attributedStringPickerAdapter))
            .disposed(by: disposeBag)
        
        Observable.just(["One", "Two", "Tree"])
            .bind(to: thirdPickerView.rx.items(adapter: viewPickerAdapter))
            .disposed(by: disposeBag)
    }
}
