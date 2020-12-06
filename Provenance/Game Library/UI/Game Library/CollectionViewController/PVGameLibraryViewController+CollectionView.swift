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
            let viewWidth = transitioningToSize?.width ?? collectionView.bounds.size.width
            let itemsPerRow: CGFloat = viewWidth > 800 ? 6 : 3

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
            let viewWidth = transitioningToSize?.width ?? collectionView.bounds.size.width
            switch item {
            case .game(let game):
                let boxartSize = CGSize(width: tvOSCellUnit, height: tvOSCellUnit / game.boxartAspectRatio.rawValue)
                return PVGameLibraryCollectionViewCell.cellSize(forImageSize: boxartSize)
            case .saves:
                // TODO: Multirow?
                let numberOfRows: CGFloat = 1.0
                let width = viewWidth //- collectionView.contentInset.left - collectionView.contentInset.right / 4
                let height = tvOSCellUnit * numberOfRows + PageIndicatorHeight
                return PVSaveStateCollectionViewCell.cellSize(forImageSize: CGSize(width: width, height: height))
            case .favorites, .recents:
                let numberOfRows: CGFloat = 1.0
                let width = viewWidth //- collectionView.contentInset.left - collectionView.contentInset.right / 5
                let height: CGFloat = tvOSCellUnit * numberOfRows + PageIndicatorHeight
                return PVSaveStateCollectionViewCell.cellSize(forImageSize: CGSize(width: width, height: height))
            }
        }
    #endif

    #if os(tvOS)
        func collectionView(_ collectionView: UICollectionView, layout _: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
            let item: Section.Item = try! collectionView.rx.model(at: IndexPath(item: 0, section: section))
            switch item {
            case .game:
                return 40
            case .saves, .favorites, .recents:
                return 0
            }
        }
    #endif

    func collectionView(_ collectionView: UICollectionView, layout _: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        let item: Section.Item? = firstModel(in: collectionView, at: section)
        switch item {
        case .none:
            return .zero
        case .some(.game):
            return minimumInteritemSpacing
        case .saves, .favorites, .recents:
            return 0
        }
    }

    func collectionView(_ collectionView: UICollectionView, layout _: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        #if os(tvOS)
            let item: Section.Item? = firstModel(in: collectionView, at: section)
            switch item {
            case .none:
                return .zero
            case .some(.game):
                return .init(top: 20, left: 20, bottom: 25, right: 20)
            case .saves:
                return .init(top: -20, left: 0, bottom: 45, right: 0)
            case .favorites:
                return .init(top: 0, left: 20, bottom: 20, right: 20)
            case .recents:
                return .init(top: 0, left: 20, bottom: 20, right: 20)
            }
        #else
        let item: Section.Item? = firstModel(in: collectionView, at: section)
        switch item {
        case .none:
            return .zero
        case .some(.game):
            return .init(top: section == 0 ? 5 : 15, left: 10, bottom: 5, right: 10)
        case .saves, .favorites, .recents:
            return .zero
        }
        #endif
    }

    private func firstModel(in collectionView: UICollectionView, at section: Int) -> Section.Item? {
        guard collectionView.numberOfItems(inSection: section) > 0 else { return nil }
        return try? collectionView.rx.model(at: IndexPath(item: 0, section: section))
    }
}
