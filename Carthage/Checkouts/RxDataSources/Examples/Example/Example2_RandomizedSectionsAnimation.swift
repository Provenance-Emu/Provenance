//
//  ViewController.swift
//  Example
//
//  Created by Krunoslav Zaher on 1/1/16.
//  Copyright © 2016 kzaher. All rights reserved.
//

import UIKit
import RxDataSources
import RxSwift
import RxCocoa
import CoreLocation

class NumberCell : UICollectionViewCell {
    @IBOutlet var value: UILabel?
}

class NumberSectionView : UICollectionReusableView {
    @IBOutlet weak var value: UILabel?
}

class PartialUpdatesViewController: UIViewController {

    @IBOutlet weak var animatedTableView: UITableView!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var animatedCollectionView: UICollectionView!
    @IBOutlet weak var refreshButton: UIButton!

    let disposeBag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()

        let initialRandomizedSections = Randomizer(rng: PseudoRandomGenerator(4, 3), sections: initialValue())

        let ticks = Observable<Int>.interval(1, scheduler: MainScheduler.instance).map { _ in () }
        let randomSections = Observable.of(ticks, refreshButton.rx.tap.asObservable())
                .merge()
                .scan(initialRandomizedSections) { a, _ in
                    return a.randomize()
                }
                .map { a in
                    return a.sections
                }
            .share(replay: 1)

        let (configureCell, titleForSection) = PartialUpdatesViewController.tableViewDataSourceUI()
        let tvAnimatedDataSource = RxTableViewSectionedAnimatedDataSource<NumberSection>(
            configureCell: configureCell,
            titleForHeaderInSection: titleForSection
        )
        let reloadDataSource = RxTableViewSectionedReloadDataSource<NumberSection>(
            configureCell: configureCell,
            titleForHeaderInSection: titleForSection
        )

        randomSections
            .bind(to: animatedTableView.rx.items(dataSource: tvAnimatedDataSource))
            .disposed(by: disposeBag)

        randomSections
            .bind(to: tableView.rx.items(dataSource: reloadDataSource))
            .disposed(by: disposeBag)

        let (configureCollectionViewCell, configureSupplementaryView) =  PartialUpdatesViewController.collectionViewDataSourceUI()
        let cvAnimatedDataSource = RxCollectionViewSectionedAnimatedDataSource(
            configureCell: configureCollectionViewCell,
            configureSupplementaryView: configureSupplementaryView
        )

        randomSections
            .bind(to: animatedCollectionView.rx.items(dataSource: cvAnimatedDataSource))
            .disposed(by: disposeBag)

        // touches

        Observable.of(
            tableView.rx.modelSelected(IntItem.self),
            animatedTableView.rx.modelSelected(IntItem.self),
            animatedCollectionView.rx.modelSelected(IntItem.self)
        )
            .merge()
            .subscribe(onNext: { item in
                print("Let me guess, it's .... It's \(item), isn't it? Yeah, I've got it.")
            })
            .disposed(by: disposeBag)
    }
}

// MARK: Skinning
extension PartialUpdatesViewController {

    static func tableViewDataSourceUI() -> (
        TableViewSectionedDataSource<NumberSection>.ConfigureCell,
        TableViewSectionedDataSource<NumberSection>.TitleForHeaderInSection
    ) {
        return (
            { (_, tv, ip, i) in
                let cell = tv.dequeueReusableCell(withIdentifier: "Cell") ?? UITableViewCell(style:.default, reuseIdentifier: "Cell")
                cell.textLabel!.text = "\(i)"
                return cell
            },
            { (ds, section) -> String? in
                return ds[section].header
            }
        )
    }

    static func collectionViewDataSourceUI() -> (
            CollectionViewSectionedDataSource<NumberSection>.ConfigureCell,
            CollectionViewSectionedDataSource<NumberSection>.ConfigureSupplementaryView
        ) {
        return (
             { (_, cv, ip, i) in
                let cell = cv.dequeueReusableCell(withReuseIdentifier: "Cell", for: ip) as! NumberCell
                cell.value!.text = "\(i)"
                return cell

            },
             { (ds ,cv, kind, ip) in
                let section = cv.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "Section", for: ip) as! NumberSectionView
                section.value!.text = "\(ds[ip.section].header)"
                return section
            }
        )
    }

    // MARK: Initial value

    func initialValue() -> [NumberSection] {
        #if true
            let nSections = 10
            let nItems = 100


            /*
            let nSections = 10
            let nItems = 2
            */

            return (0 ..< nSections).map { (i: Int) in
                NumberSection(header: "Section \(i + 1)", numbers: `$`(Array(i * nItems ..< (i + 1) * nItems)), updated: Date())
            }
        #else
            return _initialValue
        #endif
    }


}

let _initialValue: [NumberSection] = [
    NumberSection(header: "section 1", numbers: `$`([1, 2, 3]), updated: Date()),
    NumberSection(header: "section 2", numbers: `$`([4, 5, 6]), updated: Date()),
    NumberSection(header: "section 3", numbers: `$`([7, 8, 9]), updated: Date()),
    NumberSection(header: "section 4", numbers: `$`([10, 11, 12]), updated: Date()),
    NumberSection(header: "section 5", numbers: `$`([13, 14, 15]), updated: Date()),
    NumberSection(header: "section 6", numbers: `$`([16, 17, 18]), updated: Date()),
    NumberSection(header: "section 7", numbers: `$`([19, 20, 21]), updated: Date()),
    NumberSection(header: "section 8", numbers: `$`([22, 23, 24]), updated: Date()),
    NumberSection(header: "section 9", numbers: `$`([25, 26, 27]), updated: Date()),
    NumberSection(header: "section 10", numbers: `$`([28, 29, 30]), updated: Date())
]

func `$`(_ numbers: [Int]) -> [IntItem] {
    return numbers.map { IntItem(number: $0, date: Date()) }
}

