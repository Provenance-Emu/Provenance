//
//  PVGameLibraryViewController+CollectionView.swift
//  Provenance
//
//  Created by Joseph Mattiello on 5/26/18.
//  Copyright © 2018 Provenance. All rights reserved.
//

import Foundation
import PVLibrary
import PVSupport
import RxCocoa
import RxSwift

// tvOS
let tvOSCellUnit: CGFloat = 224.0 // org 256.0 = 6,  base subtract 32 for 1 more column. 224= 7, 192 = 8

// MARK: - UICollectionViewDelegateFlowLayout

extension PVGameLibraryViewController: UICollectionViewDelegateFlowLayout {
    var minimumInteritemSpacing: CGFloat {
        #if os(tvOS)
            return 24.0
        #else
            return 10.0
        #endif
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        #if os(tvOS)
            return tvos_collectionView(collectionView, layout: collectionViewLayout, sizeForItemAt: indexPath)
        #else
            return ios_collectionView(collectionView, layout: collectionViewLayout, sizeForItemAt: indexPath)
        #endif
    }

    #if os(iOS)
        private func ios_collectionView(_ collectionView: UICollectionView, layout _: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
            var height: CGFloat = PVSettingsModel.shared.showGameTitles ? 144 : 100

            let viewWidth = collectionView.bounds.size.width
            let itemsPerRow: CGFloat = viewWidth > 700 ? 6 : 3
            var width: CGFloat = (viewWidth / itemsPerRow) - (minimumInteritemSpacing * itemsPerRow * 0.67)

            let item: Section.Item = try! collectionView.rx.model(at: indexPath)
            switch item {
            case .game:
                width *= collectionViewZoom
                height *= collectionViewZoom
            case .saves, .favorites, .recents:
                // TODO: Multirow?
                let numberOfRows = 1
                width = viewWidth
                height = (height + PageIndicatorHeight + 24) * CGFloat(numberOfRows)
            }
            return .init(width: width, height: height)
        }
    #endif

    #if os(tvOS)
        private func tvos_collectionView(_ collectionView: UICollectionView, layout _: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
            let item: Section.Item = try! collectionView.rx.model(at: indexPath)
            let viewWidth = collectionView.bounds.size.width
            switch item {
            case .saves:
                // TODO: Multirow?
                let numberOfRows: CGFloat = 1.0
                let width = viewWidth // - collectionView.contentInset.left - collectionView.contentInset.right / 4
                let height = (tvOSCellUnit + PageIndicatorHeight + 24) * numberOfRows
                return PVSaveStateCollectionViewCell.cellSize(forImageSize: CGSize(width: width, height: height))
            case .favorites, .recents:
                let numberOfRows: CGFloat = 1.0
                let width = viewWidth // - collectionView.contentInset.left - collectionView.contentInset.right / 5
                let height: CGFloat = tvOSCellUnit * numberOfRows + PageIndicatorHeight
                return PVSaveStateCollectionViewCell.cellSize(forImageSize: CGSize(width: width, height: height))
            case .game(let game):
                let boxartSize = CGSize(width: ((PVSettingsModel.shared.largeGameArt ? 32 : 0) + tvOSCellUnit), height: round(((PVSettingsModel.shared.largeGameArt ? 32 : 0) + tvOSCellUnit) / game.boxartAspectRatio.rawValue))
                return PVGameLibraryCollectionViewCell.cellSize(forImageSize: boxartSize)
            }
        }
    #endif

    #if os(tvOS)
        func collectionView(_ collectionView: UICollectionView, layout _: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
            let item: Section.Item? = firstModel(in: collectionView, at: section)
            switch item {
            case .none:
                return .zero
            case .saves, .favorites, .recents:
                return 0
            case .game:
                return 55
            }
        }
    #endif

    func collectionView(_ collectionView: UICollectionView, layout _: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        #if os(tvOS)
            let item: Section.Item? = firstModel(in: collectionView, at: section)
            switch item {
            case .none:
                return .zero
            case .saves, .favorites, .recents:
                return 0
            case .some(.game):
                return minimumInteritemSpacing
            }
        #else
            let item: Section.Item? = firstModel(in: collectionView, at: section)
            switch item {
            case .none:
                return .zero
            case .some(.game):
                return minimumInteritemSpacing
            case .saves, .favorites, .recents:
                return 0
            }
        #endif
    }

    func collectionView(_ collectionView: UICollectionView, layout _: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        #if os(tvOS)
            let item: Section.Item? = firstModel(in: collectionView, at: section)
            switch item {
            case .none:
                return .zero
            case .favorites:
                return .init(top: 20, left: -53, bottom: 50, right: 53)
            case .saves:
                return .init(top: 15, left: -63, bottom: 30, right: 63)
            case .recents:
                return .init(top: 20, left: -53, bottom: 50, right: 53)
            case .some(.game):
                return .init(top: 40, left:  90, bottom: 50, right: 90)
            }
        #else
            let item: Section.Item? = firstModel(in: collectionView, at: section)
            switch item {
            case .none:
                return .zero
            case .saves, .favorites, .recents:
                return .zero
            case .some(.game):
                return .init(top: section == 0 ? 5 : 15, left: 10, bottom: 5, right: 10)
        }
        #endif
    }

    private func firstModel(in collectionView: UICollectionView, at section: Int) -> Section.Item? {
        guard collectionView.numberOfItems(inSection: section) > 0 else { return nil }
        return try? collectionView.rx.model(at: IndexPath(item: 0, section: section))
    }
}
