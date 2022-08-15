//
//  PixelateTransition.swift
//  Provenance
//
//  Created by Joseph Mattiello on 8/15/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

#if DISABLED
import UIKit
public final class PixelatePresentAnimationController: NSObject, UIViewControllerAnimatedTransitioning {
    open func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.5
    }

    open override func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard
            let toViewController = transitionContext.viewController(forKey: .to)
        else {
            return
        }
        transitionContext.containerView.addSubview(toViewController.view)
        toViewController.view.alpha = 0

        let duration = self.transitionDuration(using: transitionContext)
        UIView.animate(withDuration: duration, animations: {
            toViewController.view.layer.filters.setProperty(kCIInputScaleKey to 12...)
        }, completion: { _ in
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        })
    }
}

public protocol PixelatingTransitionController: AnyObject { }
public extension PixelatingTransitionController: UINavigationControllerDelegate {

    func navigationController(_ navigationController: UINavigationController,
                              animationControllerFor operation: UINavigationController.Operation,
                              from fromVC: UIViewController,
                              to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        switch operation {
        case .push:
            return PixelatePresentAnimationController()
        case .pop:
            return PixelatePresentAnimationController()
        default:
            return nil
        }
    }
}
#endif
