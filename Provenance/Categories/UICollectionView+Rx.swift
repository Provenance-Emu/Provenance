//
//  UICollectionView+Rx.swift
//  Provenance
//
//  Created by Dan Berglund on 2020-06-09.
//  Copyright © 2020 Provenance Emu. All rights reserved.
//

import Foundation
import RxSwift
import RxCocoa

extension Reactive where Base: UICollectionView {
    func longPressed<Model>(_ model: Model.Type) -> ControlEvent<(item: Model, at: IndexPath)> {
        let longPressRecognizer = UILongPressGestureRecognizer()
        let source: Observable<(item: Model, at: IndexPath)> = longPressRecognizer.rx.event
            .filter { $0.state == .began }
            .compactMap({ point in
                let maybeIndexPath = self.base.indexPathForItem(at: point.location(in: self.base))

                #if os(tvOS)
                    if maybeIndexPath == nil, let focusedView = UIScreen.main.focusedView as? UICollectionViewCell {
                        return self.base.indexPath(for: focusedView)
                    }
                #endif
                return maybeIndexPath
            })
            .map { indexPath in (item: try self.model(at: indexPath), at: indexPath) }
            .do(onSubscribe: {
                self.base.addGestureRecognizer(longPressRecognizer)
            }, onDispose: {
                self.base.removeGestureRecognizer(longPressRecognizer)
            })
            .share()
        return ControlEvent(events: source)
    }
}
