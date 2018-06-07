//  ActionControllerSettings.swiftg
//  XLActionController  ( https://github.com/xmartlabs/XLActionController )
//
//  Copyright (c) 2015 Xmartlabs ( http://xmartlabs.com )
//
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import UIKit

public struct ActionControllerSettings {
    
    /** Struct that contains properties to configure the actions controller's behavior  */
    public struct Behavior {
        /**
         * A Boolean value that determines whether the action controller must be dismissed when the user taps the 
         * background view. Its default value is `true`.
         */
        public var hideOnTap = true
        /**
         * A Boolean value that determines whether the action controller must be dismissed when the user scroll down 
         * the collection view. Its default value is `true`.
         *
         * @discussion If `scrollEnabled` value is `false`, this property is discarded and the action controller won't 
         * be dismissed if the user scrolls down the collection view.
         */
        public var hideOnScrollDown = true
        /**
         * A Boolean value that determines whether the collectionView's scroll is enabled. Its default value is `false`
         */
        public var scrollEnabled = false
        /**
         * A Boolean value that controls whether the collection view scroll bounces past the edge of content and back 
         * again. Its default value is `false`
         */
        public var bounces = false
        /**
         * A Boolean value that determines whether if the collection view layout will use UIDynamics to animate its 
         * items. Its default value is `false`
         */
        public var useDynamics = false
        /**
         * A Boolean value that determines whether the navigation bar will hide when action controller is being
         * presented. Its default value is `true`
         */
        public var hideNavigationBarOnShow = true
    }
    
    /** Struct that contains properties to configure the cancel view */
    public struct CancelViewStyle {
        /**
         * A Boolean value that determines whether cancel view is shown. Its default value is `false`. Its default
         * value is `false`.
         */
        public var showCancel = false
        /**
         * The cancel view's title. Its default value is "Cancel".
         */
        public var title: String? = "Cancel"
        /**
         * The cancel view's height. Its default value is `60`.
         */
        public var height = CGFloat(60.0)
        /**
         * The cancel view's background color. Its default value is `UIColor.blackColor().colorWithAlphaComponent(0.8)`.
         */
        public var backgroundColor = UIColor.black.withAlphaComponent(0.8)
        /**
          * A Boolean value that determines whether the collection view can be partially covered by the 
          * cancel view when it is pulled down. Its default value is `true`
          */
        public var hideCollectionViewBehindCancelView = false
    }

    /** Struct that contains properties to configure the collection view's style */
    public struct CollectionViewStyle {
        /** 
          * A float that determines the margins between the collection view and the container view's margins.
          * Its default value is `0`
          */
        public var lateralMargin: CGFloat = 0
        /**
          * A float that determines the cells' height when using UIDynamics to animate items. Its default value is `50`.
          */
        public var cellHeightWhenDynamicsIsUsed: CGFloat = 50
    }
  
    /** Struct that contains properties to configure the animation when presenting the action controller */
    public struct PresentAnimationStyle {
        /** 
          * A float value that is used as damping for the animation block. Its default value is `1.0`.
          * @see: animateWithDuration:delay:usingSpringWithDamping:initialSpringVelocity:options:animations:completion:
          */
        public var damping = CGFloat(1.0)
        /** 
          * A float value that is used as delay for the animation block. Its default value is `0.0`.
          * @see: animateWithDuration:delay:usingSpringWithDamping:initialSpringVelocity:options:animations:completion:
          */
        public var delay = TimeInterval(0.0)
        /** 
          * A float value that determines the animation duration. Its default value is `0.7`.
          * @see: animateWithDuration:delay:usingSpringWithDamping:initialSpringVelocity:options:animations:completion:
          */
        public var duration = TimeInterval(0.7)
        /** 
          * A float value that is used as `springVelocity` for the animation block. Its default value is `0.0`.
          * @see: animateWithDuration:delay:usingSpringWithDamping:initialSpringVelocity:options:animations:completion:
          */
        public var springVelocity = CGFloat(0.0)
        /**
          * A mask of options indicating how you want to perform the animations. Its default value is `UIViewAnimationOptions.CurveEaseOut`.
          * @see: animateWithDuration:delay:usingSpringWithDamping:initialSpringVelocity:options:animations:completion:
          */
        public var options = UIViewAnimationOptions.curveEaseOut
    }
    
    /** Struct that contains properties to configure the animation when dismissing the action controller */
    public struct DismissAnimationStyle {
        /**
         * A float value that is used as damping for the animation block. Its default value is `1.0`.
         * @see: animateWithDuration:delay:usingSpringWithDamping:initialSpringVelocity:options:animations:completion:
         */
        public var damping = CGFloat(1.0)
        /**
         * A float value that is used as delay for the animation block. Its default value is `0.0`.
         * @see: animateWithDuration:delay:usingSpringWithDamping:initialSpringVelocity:options:animations:completion:
         */
        public var delay = TimeInterval(0.0)
        /**
         * A float value that determines the animation duration. Its default value is `0.7`.
         * @see: animateWithDuration:delay:usingSpringWithDamping:initialSpringVelocity:options:animations:completion:
         */
        public var duration = TimeInterval(0.7)
        /**
         * A float value that is used as `springVelocity` for the animation block. Its default value is `0.0`.
         * @see: animateWithDuration:delay:usingSpringWithDamping:initialSpringVelocity:options:animations:completion:
         */
        public var springVelocity = CGFloat(0.0)
        /**
         * A mask of options indicating how you want to perform the animations. Its default value is `UIViewAnimationOptions.CurveEaseIn`.
         * @see: animateWithDuration:delay:usingSpringWithDamping:initialSpringVelocity:options:animations:completion:
         */
        public var options = UIViewAnimationOptions.curveEaseIn
        /**
         * A float value that makes the action controller's to be animated until the bottomof the screen plus this value.
         */
        public var offset = CGFloat(0)
    }
    
    /** Struct that contains all properties related to presentation & dismissal animations */
    public struct AnimationStyle {
        /**
         * A size value that is used to scale the presenting view controller when the action controller is being
         * presented. If `nil` is set, then the presenting view controller won't be scaled. Its default value is
         * `(0.9, 0.9)`.
         */
        public var scale: CGSize? = CGSize(width: 0.9, height: 0.9)
        /** Stores presentation animation properties */
        public var present = PresentAnimationStyle()
        /** Stores dismissal animation properties */
        public var dismiss = DismissAnimationStyle()
    }
    
    /** Struct that contains properties related to the status bar's appearance */
    public struct StatusBarStyle {
        /**
         * A Boolean value that determines whether the status bar should be visible or hidden when the action controller
         * is visible. Its default value is `true`.
         */
        public var showStatusBar = true
        /**
         * A value that determines the style of the device’s status bar when the action controller is visible. Its
         * default value is `UIStatusBarStyle.LightContent`.
         */
        public var style = UIStatusBarStyle.lightContent
        /**
         * A boolean value that determines whether the action controller takes over control of status bar appearance from the presenting 
         * view controller. Its default value is `true`.
         *
         * For more information refer to `UIViewController.modalPresentationCapturesStatusBarAppearance`, 
         * https://developer.apple.com/reference/uikit/uiviewcontroller/1621453-modalpresentationcapturesstatusb
         */
        public var modalPresentationCapturesStatusBarAppearance = true
    }
    
    /** Stores the behavior's properties values */
    public var behavior = Behavior()
    /** Stores the cancel view's properties values */
    public var cancelView = CancelViewStyle()
    /** Stores the collection view's properties values */
    public var collectionView = CollectionViewStyle()
    /** Stores the animations' properties values */
    public var animation = AnimationStyle()
    /** Stores the status bar's properties values */
    public var statusBar = StatusBarStyle()
    
    /**
     * Create the default settings
     * @return The default value for settings
     */
    public static func defaultSettings() -> ActionControllerSettings {
        return ActionControllerSettings()
    }
}
