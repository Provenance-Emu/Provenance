//
//  RxCollectionViewSectionedDataSource+Test.swift
//  Tests
//
//  Created by Krunoslav Zaher on 11/4/17.
//  Copyright © 2017 kzaher. All rights reserved.
//

#if os(iOS)

import Foundation
import RxDataSources
import XCTest
import UIKit

class RxCollectionViewSectionedDataSourceTest: XCTestCase {
}

// configureSupplementaryView not passed through init
extension RxCollectionViewSectionedDataSourceTest {
    func testCollectionViewSectionedReloadDataSource_optionalConfigureSupplementaryView() {
        let dataSource = RxCollectionViewSectionedReloadDataSource<AnimatableSectionModel<String, String>>(configureCell: { _, _, _, _  in UICollectionViewCell() })
        let layout = UICollectionViewFlowLayout()
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)

        XCTAssertFalse(dataSource.responds(to: #selector(UICollectionViewDataSource.collectionView(_:viewForSupplementaryElementOfKind:at:))))

        let sentinel = UICollectionReusableView()
        dataSource.configureSupplementaryView = { _, _, _, _ in return sentinel }

        let returnValue = dataSource.collectionView(
            collectionView,
            viewForSupplementaryElementOfKind: UICollectionElementKindSectionHeader,
            at: IndexPath(item: 0, section: 0)
        )
        XCTAssertEqual(returnValue, sentinel)
        XCTAssertTrue(dataSource.responds(to: #selector(UICollectionViewDataSource.collectionView(_:viewForSupplementaryElementOfKind:at:))))
    }

    func testCollectionViewSectionedDataSource_optionalConfigureSupplementaryView() {
        let dataSource = CollectionViewSectionedDataSource<AnimatableSectionModel<String, String>>(configureCell: { _, _, _, _  in UICollectionViewCell() })
        let layout = UICollectionViewFlowLayout()
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)

        XCTAssertFalse(dataSource.responds(to: #selector(UICollectionViewDataSource.collectionView(_:viewForSupplementaryElementOfKind:at:))))

        let sentinel = UICollectionReusableView()
        dataSource.configureSupplementaryView = { _, _, _, _ in return sentinel }

        let returnValue = dataSource.collectionView(
            collectionView,
            viewForSupplementaryElementOfKind: UICollectionElementKindSectionHeader,
            at: IndexPath(item: 0, section: 0)
        )
        XCTAssertEqual(returnValue, sentinel)
        XCTAssertTrue(dataSource.responds(to: #selector(UICollectionViewDataSource.collectionView(_:viewForSupplementaryElementOfKind:at:))))
    }
}

// configureSupplementaryView passed through init
extension RxCollectionViewSectionedDataSourceTest {
    func testCollectionViewSectionedAnimatedDataSource_optionalConfigureSupplementaryView_initializer() {
        let sentinel = UICollectionReusableView()
        let dataSource = RxCollectionViewSectionedAnimatedDataSource<AnimatableSectionModel<String, String>>(
            configureCell: { _, _, _, _  in UICollectionViewCell() },
            configureSupplementaryView: { _, _, _, _ in return sentinel }
        )
        let layout = UICollectionViewFlowLayout()
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)

        let returnValue = dataSource.collectionView(
            collectionView,
            viewForSupplementaryElementOfKind: UICollectionElementKindSectionHeader,
            at: IndexPath(item: 0, section: 0)
        )
        XCTAssertEqual(returnValue, sentinel)
        XCTAssertTrue(dataSource.responds(to: #selector(UICollectionViewDataSource.collectionView(_:viewForSupplementaryElementOfKind:at:))))
    }

    func testCollectionViewSectionedReloadDataSource_optionalConfigureSupplementaryView_initializer() {
        let sentinel = UICollectionReusableView()
        let dataSource = RxCollectionViewSectionedReloadDataSource<AnimatableSectionModel<String, String>>(
            configureCell: { _, _, _, _  in UICollectionViewCell() },
            configureSupplementaryView: { _, _, _, _ in return sentinel }
        )
        let layout = UICollectionViewFlowLayout()
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)

        let returnValue = dataSource.collectionView(
            collectionView,
            viewForSupplementaryElementOfKind: UICollectionElementKindSectionHeader,
            at: IndexPath(item: 0, section: 0)
        )
        XCTAssertEqual(returnValue, sentinel)
        XCTAssertTrue(dataSource.responds(to: #selector(UICollectionViewDataSource.collectionView(_:viewForSupplementaryElementOfKind:at:))))
    }

    func testCollectionViewSectionedDataSource_optionalConfigureSupplementaryView_initializer() {
        let sentinel = UICollectionReusableView()
        let dataSource = CollectionViewSectionedDataSource<AnimatableSectionModel<String, String>>(
            configureCell: { _, _, _, _  in UICollectionViewCell() },
            configureSupplementaryView: { _, _, _, _ in return sentinel }
        )
        let layout = UICollectionViewFlowLayout()
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)

        let returnValue = dataSource.collectionView(
            collectionView,
            viewForSupplementaryElementOfKind: UICollectionElementKindSectionHeader,
            at: IndexPath(item: 0, section: 0)
        )
        XCTAssertEqual(returnValue, sentinel)
        XCTAssertTrue(dataSource.responds(to: #selector(UICollectionViewDataSource.collectionView(_:viewForSupplementaryElementOfKind:at:))))
    }
}

#endif
