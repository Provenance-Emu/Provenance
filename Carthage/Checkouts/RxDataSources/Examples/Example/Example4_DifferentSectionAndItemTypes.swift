//
//  MultipleSectionModelViewController.swift
//  RxDataSources
//
//  Created by Segii Shulga on 4/26/16.
//  Copyright © 2016 kzaher. All rights reserved.
//

import UIKit
import RxDataSources
import RxCocoa
import RxSwift
import Differentiator

// the trick is to just use enum for different section types
class MultipleSectionModelViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    let disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let sections: [MultipleSectionModel] = [
            .ImageProvidableSection(title: "Section 1",
                items: [.ImageSectionItem(image: UIImage(named: "settings")!, title: "General")]),
            .ToggleableSection(title: "Section 2",
                items: [.ToggleableSectionItem(title: "On", enabled: true)]),
            .StepperableSection(title: "Section 3",
                items: [.StepperSectionItem(title: "1")])
        ]
        
        let dataSource = MultipleSectionModelViewController.dataSource()
        
        Observable.just(sections)
            .bind(to: tableView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)
    }
}

extension MultipleSectionModelViewController {
    static func dataSource() -> RxTableViewSectionedReloadDataSource<MultipleSectionModel> {
        return RxTableViewSectionedReloadDataSource<MultipleSectionModel>(
            configureCell: { (dataSource, table, idxPath, _) in
                switch dataSource[idxPath] {
                case let .ImageSectionItem(image, title):
                    let cell: ImageTitleTableViewCell = table.dequeueReusableCell(forIndexPath: idxPath)
                    cell.titleLabel.text = title
                    cell.cellImageView.image = image

                    return cell
                case let .StepperSectionItem(title):
                    let cell: TitleSteperTableViewCell = table.dequeueReusableCell(forIndexPath: idxPath)
                    cell.titleLabel.text = title

                    return cell
                case let .ToggleableSectionItem(title, enabled):
                    let cell: TitleSwitchTableViewCell = table.dequeueReusableCell(forIndexPath: idxPath)
                    cell.switchControl.isOn = enabled
                    cell.titleLabel.text = title

                    return cell
                }
            },
            titleForHeaderInSection: { dataSource, index in
                let section = dataSource[index]
                return section.title
            }
        )
    }
}

enum MultipleSectionModel {
    case ImageProvidableSection(title: String, items: [SectionItem])
    case ToggleableSection(title: String, items: [SectionItem])
    case StepperableSection(title: String, items: [SectionItem])
}

enum SectionItem {
    case ImageSectionItem(image: UIImage, title: String)
    case ToggleableSectionItem(title: String, enabled: Bool)
    case StepperSectionItem(title: String)
}

extension MultipleSectionModel: SectionModelType {
    typealias Item = SectionItem
    
    var items: [SectionItem] {
        switch  self {
        case .ImageProvidableSection(title: _, items: let items):
            return items.map {$0}
        case .StepperableSection(title: _, items: let items):
            return items.map {$0}
        case .ToggleableSection(title: _, items: let items):
            return items.map {$0}
        }
    }
    
    init(original: MultipleSectionModel, items: [Item]) {
        switch original {
        case let .ImageProvidableSection(title: title, items: _):
            self = .ImageProvidableSection(title: title, items: items)
        case let .StepperableSection(title, _):
            self = .StepperableSection(title: title, items: items)
        case let .ToggleableSection(title, _):
            self = .ToggleableSection(title: title, items: items)
        }
    }
}

extension MultipleSectionModel {
    var title: String {
        switch self {
        case .ImageProvidableSection(title: let title, items: _):
            return title
        case .StepperableSection(title: let title, items: _):
            return title
        case .ToggleableSection(title: let title, items: _):
            return title
        }
    }
}
