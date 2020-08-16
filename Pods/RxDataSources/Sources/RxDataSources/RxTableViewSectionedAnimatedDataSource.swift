//
//  RxTableViewSectionedAnimatedDataSource.swift
//  RxExample
//
//  Created by Krunoslav Zaher on 6/27/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

#if os(iOS) || os(tvOS)
import Foundation
import UIKit
#if !RX_NO_MODULE
import RxSwift
import RxCocoa
#endif
import Differentiator

open class RxTableViewSectionedAnimatedDataSource<Section: AnimatableSectionModelType>
    : TableViewSectionedDataSource<Section>
    , RxTableViewDataSourceType {
    public typealias Element = [Section]
    public typealias DecideViewTransition = (TableViewSectionedDataSource<Section>, UITableView, [Changeset<Section>]) -> ViewTransition

    /// Animation configuration for data source
    public var animationConfiguration: AnimationConfiguration

    /// Calculates view transition depending on type of changes
    public var decideViewTransition: DecideViewTransition

    #if os(iOS)
        public init(
                animationConfiguration: AnimationConfiguration = AnimationConfiguration(),
                decideViewTransition: @escaping DecideViewTransition = { _, _, _ in .animated },
                configureCell: @escaping ConfigureCell,
                titleForHeaderInSection: @escaping  TitleForHeaderInSection = { _, _ in nil },
                titleForFooterInSection: @escaping TitleForFooterInSection = { _, _ in nil },
                canEditRowAtIndexPath: @escaping CanEditRowAtIndexPath = { _, _ in false },
                canMoveRowAtIndexPath: @escaping CanMoveRowAtIndexPath = { _, _ in false },
                sectionIndexTitles: @escaping SectionIndexTitles = { _ in nil },
                sectionForSectionIndexTitle: @escaping SectionForSectionIndexTitle = { _, _, index in index }
            ) {
            self.animationConfiguration = animationConfiguration
            self.decideViewTransition = decideViewTransition
            super.init(
                configureCell: configureCell,
               titleForHeaderInSection: titleForHeaderInSection,
               titleForFooterInSection: titleForFooterInSection,
               canEditRowAtIndexPath: canEditRowAtIndexPath,
               canMoveRowAtIndexPath: canMoveRowAtIndexPath,
               sectionIndexTitles: sectionIndexTitles,
               sectionForSectionIndexTitle: sectionForSectionIndexTitle
            )
        }
    #else
        public init(
                animationConfiguration: AnimationConfiguration = AnimationConfiguration(),
                decideViewTransition: @escaping DecideViewTransition = { _, _, _ in .animated },
                configureCell: @escaping ConfigureCell,
                titleForHeaderInSection: @escaping  TitleForHeaderInSection = { _, _ in nil },
                titleForFooterInSection: @escaping TitleForFooterInSection = { _, _ in nil },
                canEditRowAtIndexPath: @escaping CanEditRowAtIndexPath = { _, _ in false },
                canMoveRowAtIndexPath: @escaping CanMoveRowAtIndexPath = { _, _ in false }
            ) {
            self.animationConfiguration = animationConfiguration
            self.decideViewTransition = decideViewTransition
            super.init(
                configureCell: configureCell,
               titleForHeaderInSection: titleForHeaderInSection,
               titleForFooterInSection: titleForFooterInSection,
               canEditRowAtIndexPath: canEditRowAtIndexPath,
               canMoveRowAtIndexPath: canMoveRowAtIndexPath
            )
        }
    #endif

    var dataSet = false

    open func tableView(_ tableView: UITableView, observedEvent: Event<Element>) {
        Binder(self) { dataSource, newSections in
            #if DEBUG
                dataSource._dataSourceBound = true
            #endif
            if !dataSource.dataSet {
                dataSource.dataSet = true
                dataSource.setSections(newSections)
                tableView.reloadData()
            }
            else {
                // if view is not in view hierarchy, performing batch updates will crash the app
                if tableView.window == nil {
                    dataSource.setSections(newSections)
                    tableView.reloadData()
                    return
                }
                let oldSections = dataSource.sectionModels
                do {
                    let differences = try Diff.differencesForSectionedView(initialSections: oldSections, finalSections: newSections)
                    
                    switch dataSource.decideViewTransition(dataSource, tableView, differences) {
                    case .animated:
                        // each difference must be run in a separate 'performBatchUpdates', otherwise it crashes.
                        // this is a limitation of Diff tool
                        for difference in differences {
                            let updateBlock = {
                                // sections must be set within updateBlock in 'performBatchUpdates'
                                dataSource.setSections(difference.finalSections)
                                tableView.batchUpdates(difference, animationConfiguration: dataSource.animationConfiguration)
                            }
                            if #available(iOS 11, tvOS 11, *) {
                                tableView.performBatchUpdates(updateBlock, completion: nil)
                            } else {
                                tableView.beginUpdates()
                                updateBlock()
                                tableView.endUpdates()
                            }
                        }
                        
                    case .reload:
                        dataSource.setSections(newSections)
                        tableView.reloadData()
                        return
                    }
                }
                catch let e {
                    rxDebugFatalError(e)
                    dataSource.setSections(newSections)
                    tableView.reloadData()
                }
            }
        }.on(observedEvent)
    }
}
#endif
