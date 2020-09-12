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
    func longPressed<Model>(_ model: Model.Type) -> ControlEvent<(item: Model, at: IndexPath, point: CGPoint)> {
        let longPressRecognizer = UILongPressGestureRecognizer()
        let source: Observable<(item: Model, at: IndexPath, point: CGPoint)> = longPressRecognizer.rx.event
            .filter { $0.state == .began }
            .compactMap({ event -> (IndexPath, CGPoint)? in
                let point = event.location(in: self.base)
                var maybeIndexPath = self.base.indexPathForItem(at: point)

                #if os(tvOS)
                    if maybeIndexPath == nil, let focusedView = UIScreen.main.focusedView as? UICollectionViewCell {
                        maybeIndexPath = self.base.indexPath(for: focusedView)
                    }
                #endif
                guard let indexPath = maybeIndexPath else { return nil }
                return (indexPath, point)
            })
            .map { indexPath, point in (item: try self.model(at: indexPath), at: indexPath, point: point) }
            .do(onSubscribe: {
                self.base.addGestureRecognizer(longPressRecognizer)
            }, onDispose: {
                self.base.removeGestureRecognizer(longPressRecognizer)
            })
            .share()
        return ControlEvent(events: source)
    }
}
