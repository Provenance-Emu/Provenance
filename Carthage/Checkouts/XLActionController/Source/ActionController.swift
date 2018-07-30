//  XLActionController.swift
//  XLActionController ( https://github.com/xmartlabs/XLActionController )
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

import Foundation
import UIKit

// MARK: - Section class

open class Section<ActionDataType, SectionHeaderDataType> {
    
    open var data: SectionHeaderDataType? {
        get { return _data?.data }
        set { _data = RawData(data: newValue) }
    }
    open var actions = [Action<ActionDataType>]()
    fileprivate var _data: RawData<SectionHeaderDataType>?

    public init() {}
}

// MARK: - Enum definitions

public enum CellSpec<CellType: UICollectionViewCell, CellDataType> {
    
    case nibFile(nibName: String, bundle: Bundle?, height:((CellDataType)-> CGFloat))
    case cellClass(height:((CellDataType)-> CGFloat))
    
    public var height: ((CellDataType) -> CGFloat) {
        switch self {
        case .cellClass(let heightCallback):
            return heightCallback
        case .nibFile(_, _, let heightCallback):
            return heightCallback
        }
    }
}

public enum HeaderSpec<HeaderType: UICollectionReusableView, HeaderDataType> {
    
    case nibFile(nibName: String, bundle: Bundle?, height:((HeaderDataType) -> CGFloat))
    case cellClass(height:((HeaderDataType) -> CGFloat))
    
    public var height: ((HeaderDataType) -> CGFloat) {
        switch self {
        case .cellClass(let heightCallback):
            return heightCallback
        case .nibFile(_, _, let heightCallback):
            return heightCallback
        }
    }
}

private enum ReusableViewIds: String {
    case Cell = "Cell"
    case Header = "Header"
    case SectionHeader = "SectionHeader"
}

// MARK: - Row class

final class RawData<T> {
    var data: T!
    
    init?(data: T?) {
        guard let data = data else { return nil }
        self.data = data
    }
}

// MARK: - ActionController class

open class ActionController<ActionViewType: UICollectionViewCell, ActionDataType, HeaderViewType: UICollectionReusableView, HeaderDataType, SectionHeaderViewType: UICollectionReusableView, SectionHeaderDataType>: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UIViewControllerTransitioningDelegate, UIViewControllerAnimatedTransitioning {
 
    // MARK - Public properties
    
    open var headerData: HeaderDataType? {
        set { _headerData = RawData(data: newValue) }
        get { return _headerData?.data }
    }

    open var settings: ActionControllerSettings = ActionControllerSettings.defaultSettings()
    
    open var cellSpec: CellSpec<ActionViewType, ActionDataType>
    open var sectionHeaderSpec: HeaderSpec<SectionHeaderViewType, SectionHeaderDataType>?
    open var headerSpec: HeaderSpec<HeaderViewType, HeaderDataType>?
    
    open var onConfigureHeader: ((HeaderViewType, HeaderDataType) -> ())?
    open var onConfigureSectionHeader: ((SectionHeaderViewType, SectionHeaderDataType) -> ())?
    open var onConfigureCellForAction: ((ActionViewType, Action<ActionDataType>, IndexPath) -> ())?
    
    open var contentHeight: CGFloat = 0.0

    open var safeAreaInsets: UIEdgeInsets {
        if #available(iOS 11, *) {
            return view.safeAreaInsets
        }
        return .zero
    }

    open var cancelView: UIView?

    lazy open var backgroundView: UIView = {
        let backgroundView = UIView()
        backgroundView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        backgroundView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        return backgroundView
    }()

    lazy open var collectionView: UICollectionView = { [unowned self] in
        let collectionView = UICollectionView(frame: UIScreen.main.bounds, collectionViewLayout: self.collectionViewLayout)
        collectionView.alwaysBounceVertical = self.settings.behavior.bounces
        collectionView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        collectionView.backgroundColor = .clear
        collectionView.bounces = self.settings.behavior.bounces
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.isScrollEnabled = self.settings.behavior.scrollEnabled
        collectionView.showsVerticalScrollIndicator = false
        if self.settings.behavior.hideOnTap {
            let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(ActionController.tapGestureDidRecognize(_:)))
            collectionView.backgroundView = UIView(frame: collectionView.bounds)
            collectionView.backgroundView?.isUserInteractionEnabled = true
            collectionView.backgroundView?.addGestureRecognizer(tapRecognizer)
        }
        if self.settings.behavior.hideOnScrollDown && !self.settings.behavior.scrollEnabled {
            let swipeGesture = UISwipeGestureRecognizer(target: self, action: #selector(ActionController.swipeGestureDidRecognize(_:)))
            swipeGesture.direction = .down
            collectionView.addGestureRecognizer(swipeGesture)
        }
        return collectionView
    }()
    
    lazy open var collectionViewLayout: DynamicCollectionViewFlowLayout = { [unowned self] in
        let collectionViewLayout = DynamicCollectionViewFlowLayout()
        collectionViewLayout.useDynamicAnimator = self.settings.behavior.useDynamics
        collectionViewLayout.minimumInteritemSpacing = 0.0
        collectionViewLayout.minimumLineSpacing = 0
        return collectionViewLayout
    }()

    open var presentingNavigationController: UINavigationController? {
        return (presentingViewController as? UINavigationController) ?? presentingViewController?.navigationController
    }

    // MARK: - ActionController initializers
    
    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        cellSpec = .cellClass(height: { _ -> CGFloat in 60 })
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        transitioningDelegate = self
        modalPresentationStyle = .custom
    }
    
    public required init?(coder aDecoder: NSCoder) {
        cellSpec = .cellClass(height: { _ -> CGFloat in 60 })
        super.init(coder: aDecoder)
        transitioningDelegate = self
        modalPresentationStyle = .custom
    }
    
    // MARK - Public API

    open func addAction(_ action: Action<ActionDataType>) {
        if let section = _sections.last {
            section.actions.append(action)
        } else {
            let section = Section<ActionDataType, SectionHeaderDataType>()
            addSection(section)
            section.actions.append(action)
        }
    }

    @discardableResult
    open func addSection(_ section: Section<ActionDataType, SectionHeaderDataType>) -> Section<ActionDataType, SectionHeaderDataType> {
        _sections.append(section)
        return section
    }
    
    // MARK: - Helpers
    
    open func sectionForIndex(_ index: Int) -> Section<ActionDataType, SectionHeaderDataType>? {
        return _sections[index]
    }
    
    open func actionForIndexPath(_ indexPath: IndexPath) -> Action<ActionDataType>? {
        return _sections[(indexPath as NSIndexPath).section].actions[(indexPath as NSIndexPath).item]
    }
    
    open func actionIndexPathFor(_ indexPath: IndexPath) -> IndexPath {
        if hasHeader() {
            return IndexPath(item: (indexPath as NSIndexPath).item, section: (indexPath as NSIndexPath).section - 1)
        }
        return indexPath
    }
    
    open func dismiss() {
        dismiss(nil)
    }

    open func dismiss(_ completion: (() -> ())?) {
        disableActions = true
        presentingViewController?.dismiss(animated: true) { [weak self] in
            self?.disableActions = false
            completion?()
        }
    }
    
    // MARK: - View controller behavior
    
    open override func viewDidLoad() {
        super.viewDidLoad()

        modalPresentationCapturesStatusBarAppearance = settings.statusBar.modalPresentationCapturesStatusBarAppearance

        // background view
        view.addSubview(backgroundView)

        // register main cell
        switch cellSpec {
        case .nibFile(let nibName, let bundle, _):
            collectionView.register(UINib(nibName: nibName, bundle: bundle), forCellWithReuseIdentifier:ReusableViewIds.Cell.rawValue)
        case .cellClass:
            collectionView.register(ActionViewType.self, forCellWithReuseIdentifier:ReusableViewIds.Cell.rawValue)
        }
        
        if #available(iOS 11.0, *) {
            collectionView.contentInsetAdjustmentBehavior = .never
        }
        
        // register main header
        if let headerSpec = headerSpec, let _ = headerData {
            switch headerSpec {
            case .cellClass:
                collectionView.register(HeaderViewType.self, forSupplementaryViewOfKind:UICollectionElementKindSectionHeader, withReuseIdentifier: ReusableViewIds.Header.rawValue)
            case .nibFile(let nibName, let bundle, _):
                collectionView.register(UINib(nibName: nibName, bundle: bundle), forSupplementaryViewOfKind:UICollectionElementKindSectionHeader, withReuseIdentifier: ReusableViewIds.Header.rawValue)
            }
        }
        
        // register section header
        if let headerSpec = sectionHeaderSpec {
            switch headerSpec {
            case .cellClass:
                collectionView.register(SectionHeaderViewType.self, forSupplementaryViewOfKind:UICollectionElementKindSectionHeader, withReuseIdentifier: ReusableViewIds.SectionHeader.rawValue)
            case .nibFile(let nibName, let bundle, _):
                collectionView.register(UINib(nibName: nibName, bundle: bundle), forSupplementaryViewOfKind:UICollectionElementKindSectionHeader, withReuseIdentifier: ReusableViewIds.SectionHeader.rawValue)
            }
        }
        
        view.addSubview(collectionView)
        
        // calculate content Inset
        collectionView.layoutSubviews()
        if let section = _sections.last, !settings.behavior.useDynamics {
            let lastSectionIndex = _sections.count - 1
            let layoutAtts = collectionViewLayout.layoutAttributesForItem(at: IndexPath(item: section.actions.count - 1, section: hasHeader() ? lastSectionIndex + 1 : lastSectionIndex))
            contentHeight = layoutAtts!.frame.origin.y + layoutAtts!.frame.size.height

            if settings.cancelView.showCancel && !settings.cancelView.hideCollectionViewBehindCancelView {
                contentHeight += settings.cancelView.height
            }
        }

        setUpContentInsetForHeight(view.frame.height)
        
        // set up collection view initial position taking into account top content inset
        collectionView.frame = view.bounds
        collectionView.frame.origin.y += contentHeight + (settings.cancelView.showCancel ? settings.cancelView.height : 0)
        collectionViewLayout.footerReferenceSize = CGSize(width: 320, height: 0)
        // -
        
        if settings.cancelView.showCancel {
            cancelView = cancelView ?? createCancelView()
            view.addSubview(cancelView!)
        }
    }

    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        backgroundView.frame = view.bounds

        if let navController = presentingNavigationController, settings.behavior.hideNavigationBarOnShow {
            navigationBarWasHiddenAtStart = navController.isNavigationBarHidden
            navController.setNavigationBarHidden(true, animated: animated)
        }
    }

    open override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let navController = presentingNavigationController, settings.behavior.hideNavigationBarOnShow {
            navController.setNavigationBarHidden(navigationBarWasHiddenAtStart, animated: animated)
        }
    }

    @available(iOS 11.0, *)
    open override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        setUpContentInsetForHeight(view.frame.height)
        updateCancelViewLayout()
    }

    open override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        collectionView.setNeedsLayout()
        
        if let _ = settings.animation.scale {
            presentingViewController?.view.transform = CGAffineTransform.identity
        }
        
        collectionView.collectionViewLayout.invalidateLayout()
        
        coordinator.animate(alongsideTransition: { [weak self] _ in
            self?.setUpContentInsetForHeight(size.height)
            self?.collectionView.reloadData()
            if let scale = self?.settings.animation.scale {
                self?.presentingViewController?.view.transform = CGAffineTransform(scaleX: scale.width, y: scale.height)
            }
        }, completion: nil)
        
        
        collectionView.layoutIfNeeded()
    }

    override open func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        collectionView.collectionViewLayout.invalidateLayout()
    }
    
    open override var prefersStatusBarHidden: Bool {
        return !settings.statusBar.showStatusBar
    }
    
    open override var preferredStatusBarStyle : UIStatusBarStyle {
        return settings.statusBar.style
    }

    open func createCancelView() -> UIView {
        let cancelView = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: settings.cancelView.height + safeAreaInsets.bottom))
        cancelView.autoresizingMask = [.flexibleWidth, .flexibleTopMargin]
        cancelView.backgroundColor = settings.cancelView.backgroundColor

        let cancelButton = UIButton(frame: CGRect(x: 0, y: 0, width: 100, height: settings.cancelView.height))
        cancelButton.addTarget(self, action: #selector(ActionController.cancelButtonDidTouch(_:)), for: .touchUpInside)
        cancelButton.setTitle(settings.cancelView.title, for: UIControlState())
        cancelButton.translatesAutoresizingMaskIntoConstraints = false

        cancelView.addSubview(cancelButton)

        let metrics = ["height": settings.cancelView.height]
        cancelView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[button]|", options: [], metrics: metrics, views: ["button": cancelButton]))
        cancelView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[button(height)]", options: [], metrics: metrics, views: ["button": cancelButton]))

        return cancelView
    }

    open func updateCancelViewLayout() {
        guard settings.cancelView.showCancel, let cancelView = self.cancelView else {
            return
        }
        cancelView.frame.size.height = settings.cancelView.height + safeAreaInsets.bottom
    }

    // MARK: - UICollectionViewDataSource
    
    open func numberOfSections(in collectionView: UICollectionView) -> Int {
        return numberOfSections()
    }
    
    open func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
      if hasHeader() && section == 0 { return 0 }
      let rows = _sections[actionSectionIndexFor(section)].actions.count

      guard let dynamicSectionIndex = _dynamicSectionIndex else {
        return settings.behavior.useDynamics ? 0 : rows
      }
      if settings.behavior.useDynamics && section > dynamicSectionIndex {
        return 0
      }
      return rows
    }

    open func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if kind == UICollectionElementKindSectionHeader {
            if (indexPath as NSIndexPath).section == 0 && hasHeader() {
                let reusableview = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: ReusableViewIds.Header.rawValue, for: indexPath) as? HeaderViewType
                onConfigureHeader?(reusableview!, headerData!)
                return reusableview!
            } else {
                let reusableview = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: ReusableViewIds.SectionHeader.rawValue, for: indexPath) as? SectionHeaderViewType
                onConfigureSectionHeader?(reusableview!,  sectionForIndex(actionSectionIndexFor((indexPath as NSIndexPath).section))!.data!)
                return reusableview!
            }
        }
        
        fatalError()
    }
    
    open func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let action = actionForIndexPath(actionIndexPathFor(indexPath))
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ReusableViewIds.Cell.rawValue, for: indexPath) as? ActionViewType
        self.onConfigureCellForAction?(cell!, action!, indexPath)
        return cell!
    }
    
    // MARK: - UICollectionViewDelegate & UICollectionViewDelegateFlowLayout
    
    open func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        let cell = collectionView.cellForItem(at: indexPath) as? ActionViewType
        (cell as? SeparatorCellType)?.hideSeparator()
        if let prevCell = prevCell(indexPath) {
            (prevCell as? SeparatorCellType)?.hideSeparator()
        }
        return true
    }
    
    open func collectionView(_ collectionView: UICollectionView, didUnhighlightItemAt indexPath: IndexPath) {
        let cell = collectionView.cellForItem(at: indexPath) as? ActionViewType
        (cell as? SeparatorCellType)?.showSeparator()
        if let prevCell = prevCell(indexPath) {
            (prevCell as? SeparatorCellType)?.showSeparator()
        }
    }
    
    open func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        return !disableActions && actionForIndexPath(actionIndexPathFor(indexPath))?.enabled == true
    }
    
    open func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let action = self.actionForIndexPath(actionIndexPathFor(indexPath))

        if let action = action, action.executeImmediatelyOnTouch {
            action.handler?(action)
        }

        self.dismiss() {
            if let action = action, !action.executeImmediatelyOnTouch {
                action.handler?(action)
            }
        }
    }

    open func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        guard let action = self.actionForIndexPath(actionIndexPathFor(indexPath)), let actionData = action.data else {
            return CGSize.zero
        }

        let referenceWidth = collectionView.bounds.size.width
        let margins = 2 * settings.collectionView.lateralMargin + collectionView.contentInset.left + collectionView.contentInset.right
        return CGSize(width: referenceWidth - margins, height: cellSpec.height(actionData))
    }
    
    open func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        if section == 0 {
            if let headerData = headerData, let headerSpec = headerSpec {
                return CGSize(width: collectionView.bounds.size.width, height: headerSpec.height(headerData))
            } else if let sectionHeaderSpec = sectionHeaderSpec, let section = sectionForIndex(actionSectionIndexFor(section)), let sectionData = section.data {
                return CGSize(width: collectionView.bounds.size.width, height: sectionHeaderSpec.height(sectionData))
            }
        } else if let sectionHeaderSpec = sectionHeaderSpec, let section = sectionForIndex(actionSectionIndexFor(section)), let sectionData = section.data {
            return CGSize(width: collectionView.bounds.size.width, height: sectionHeaderSpec.height(sectionData))
        }
        return CGSize.zero
    }
    
    open func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        return CGSize.zero
    }
    
    // MARK: - UIViewControllerTransitioningDelegate
    
    open func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        isPresenting = true
        return self
    }
    
    open func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        isPresenting = false
        return self
    }

    // MARK: - UIViewControllerAnimatedTransitioning
    
    open func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return isPresenting ? 0 : settings.animation.dismiss.duration
    }
    
    open func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let containerView = transitionContext.containerView
        
        let fromViewController = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.from)!
        let fromView = fromViewController.view
        
        let toViewController = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.to)!
        let toView = toViewController.view
        
        if isPresenting {
            toView?.autoresizingMask = [.flexibleHeight, .flexibleWidth]
            containerView.addSubview(toView!)
            
            transitionContext.completeTransition(true)
            presentView(toView!, presentingView: fromView!, animationDuration: settings.animation.present.duration, completion: nil)
        } else {
            dismissView(fromView!, presentingView: toView!, animationDuration: settings.animation.dismiss.duration) { completed in
                if completed {
                    fromView?.removeFromSuperview()
                }
                transitionContext.completeTransition(completed)
            }
        }
    }
    
    open func presentView(_ presentedView: UIView, presentingView: UIView, animationDuration: Double, completion: ((_ completed: Bool) -> Void)?) {
        onWillPresentView()
        let animationSettings = settings.animation.present
        UIView.animate(withDuration: animationDuration,
            delay: animationSettings.delay,
            usingSpringWithDamping: animationSettings.damping,
            initialSpringVelocity: animationSettings.springVelocity,
            options: animationSettings.options.union(.allowUserInteraction),
            animations: { [weak self] in
                if let transformScale = self?.settings.animation.scale {
                    presentingView.transform = CGAffineTransform(scaleX: transformScale.width, y: transformScale.height)
                }
                self?.performCustomPresentationAnimation(presentedView, presentingView: presentingView)
            },
            completion: { [weak self] finished in
                self?.onDidPresentView()
                completion?(finished)
            })
    }
    
    open func dismissView(_ presentedView: UIView, presentingView: UIView, animationDuration: Double, completion: ((_ completed: Bool) -> Void)?) {
        onWillDismissView()
        let animationSettings = settings.animation.dismiss
        
        UIView.animate(withDuration: animationDuration,
            delay: animationSettings.delay,
            usingSpringWithDamping: animationSettings.damping,
            initialSpringVelocity: animationSettings.springVelocity,
            options: animationSettings.options.union(.allowUserInteraction),
            animations: { [weak self] in
                if let _ = self?.settings.animation.scale {
                    presentingView.transform = CGAffineTransform.identity
                }
                self?.performCustomDismissingAnimation(presentedView, presentingView: presentingView)
            },
            completion: { [weak self] _ in
                self?.onDidDismissView()
                completion?(true)
            })
    }
    
    open func onWillPresentView() {
        backgroundView.alpha = 0.0
        cancelView?.frame.origin.y = view.bounds.size.height
        collectionView.collectionViewLayout.invalidateLayout()
        collectionView.layoutSubviews()
        // Override this to add custom behavior previous to start presenting view animated.
        // Tip: you could start a new animation from this method
    }
    
    open func performCustomPresentationAnimation(_ presentedView: UIView, presentingView: UIView) {
        backgroundView.alpha = 1.0
        cancelView?.frame.origin.y = view.bounds.size.height - settings.cancelView.height - safeAreaInsets.bottom
        collectionView.frame = view.bounds
        // Override this to add custom animations. This method is performed within the presentation animation block
    }
    
    open func onDidPresentView() {
        // Override this to add custom behavior when the presentation animation block finished
    }
    
    open func onWillDismissView() {
        // Override this to add custom behavior previous to start dismissing view animated
        // Tip: you could start a new animation from this method
    }
    
    open func performCustomDismissingAnimation(_ presentedView: UIView, presentingView: UIView) {
        backgroundView.alpha = 0.0
        cancelView?.frame.origin.y = view.bounds.size.height
        collectionView.frame.origin.y = contentHeight + (settings.cancelView.showCancel ? settings.cancelView.height : 0) + settings.animation.dismiss.offset
        // Override this to add custom animations. This method is performed within the presentation animation block
    }
    
    open func onDidDismissView() {
        // Override this to add custom behavior when the presentation animation block finished
    }
    
    // MARK: - Event handlers
    
    @objc func cancelButtonDidTouch(_ sender: UIButton) {
        self.dismiss()
    }
    
    @objc func tapGestureDidRecognize(_ gesture: UITapGestureRecognizer) {
        self.dismiss()
    }
    
    @objc func swipeGestureDidRecognize(_ gesture: UISwipeGestureRecognizer) {
        self.dismiss()
    }
    
    // MARK: - Internal helpers
    
    func prevCell(_ indexPath: IndexPath) -> ActionViewType? {
        let prevPath: IndexPath?
        switch (indexPath as NSIndexPath).item {
        case 0 where (indexPath as NSIndexPath).section > 0:
            prevPath = IndexPath(item: collectionView(collectionView, numberOfItemsInSection: (indexPath as NSIndexPath).section - 1) - 1, section: (indexPath as NSIndexPath).section - 1)
        case let x where x > 0:
            prevPath = IndexPath(item: x - 1, section: (indexPath as NSIndexPath).section)
        default:
            prevPath = nil
        }
        
        guard let unwrappedPrevPath = prevPath else { return nil }
        
        return collectionView.cellForItem(at: unwrappedPrevPath) as? ActionViewType
    }

    func hasHeader() -> Bool {
        return headerData != nil && headerSpec != nil
    }
    
    fileprivate func numberOfActions() -> Int {
        return _sections.flatMap({ $0.actions }).count
    }
        
    fileprivate func numberOfSections() -> Int {
        return hasHeader() ? _sections.count + 1 : _sections.count
    }
    
    fileprivate func actionSectionIndexFor(_ section: Int) -> Int {
        return hasHeader() ? section - 1 : section
    }

    fileprivate func setUpContentInsetForHeight(_ height: CGFloat) {
        if initialContentInset == nil {
            initialContentInset = collectionView.contentInset
        }
        var leftInset = initialContentInset.left
        var rightInset = initialContentInset.right
        var bottomInset = settings.cancelView.showCancel ? settings.cancelView.height : initialContentInset.bottom
        var topInset = height - contentHeight - safeAreaInsets.bottom

        if settings.cancelView.showCancel {
            topInset -= settings.cancelView.height
        }

        topInset = max(topInset, 30)

        bottomInset += safeAreaInsets.bottom
        leftInset += safeAreaInsets.left
        rightInset += safeAreaInsets.right
        topInset += safeAreaInsets.top

        collectionView.contentInset = UIEdgeInsets(top: topInset, left: leftInset, bottom: bottomInset, right: rightInset)
        if !settings.behavior.useDynamics {
            collectionView.contentOffset.y = -height + contentHeight + safeAreaInsets.bottom
        }
    }

    // MARK: - Private properties

    fileprivate var navigationBarWasHiddenAtStart = false
    fileprivate var initialContentInset: UIEdgeInsets!

    fileprivate var disableActions = false
    fileprivate var isPresenting = false

    fileprivate var _dynamicSectionIndex: Int?
    fileprivate var _headerData: RawData<HeaderDataType>?
    fileprivate var _sections = [Section<ActionDataType, SectionHeaderDataType>]()
}

// MARK: - DynamicsActionController class

open class DynamicsActionController<ActionViewType: UICollectionViewCell, ActionDataType, HeaderViewType: UICollectionReusableView, HeaderDataType, SectionHeaderViewType: UICollectionReusableView, SectionHeaderDataType> : ActionController<ActionViewType, ActionDataType, HeaderViewType, HeaderDataType, SectionHeaderViewType, SectionHeaderDataType> {

    open lazy var animator: UIDynamicAnimator = {
        return UIDynamicAnimator()
    }()
    
    open lazy var gravityBehavior: UIGravityBehavior = {
        let gravity = UIGravityBehavior(items: [self.collectionView])
        gravity.magnitude = 10
        return gravity
    }()
    
    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        settings.behavior.useDynamics = true
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        settings.behavior.useDynamics = true
    }
 
    open override func viewDidLoad() {
        super.viewDidLoad()
        
        collectionView.frame = view.bounds

        contentHeight = CGFloat(numberOfActions()) * settings.collectionView.cellHeightWhenDynamicsIsUsed + (CGFloat(_sections.count) * (collectionViewLayout.sectionInset.top + collectionViewLayout.sectionInset.bottom))
        contentHeight += collectionView.contentInset.bottom
        
        setUpContentInsetForHeight(view.frame.height)

        view.setNeedsLayout()
        view.layoutIfNeeded()
    }

    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        for (index, section) in _sections.enumerated() {
            var rowIndex = -1
            let indexPaths = section.actions.map({ _ -> IndexPath in
                rowIndex += 1
                return IndexPath(row: rowIndex, section: index)
            })
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(0.3 * Double(index) * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: {
                self._dynamicSectionIndex = index
                self.collectionView.performBatchUpdates({
                    if indexPaths.count > 0 {
                        self.collectionView.insertItems(at: indexPaths)
                    }
                }, completion: nil)
            })
        }
    }
    
    // MARK: - UICollectionViewDelegate & UICollectionViewDelegateFlowLayout
    
    open override func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        guard let alignment = (collectionViewLayout as? DynamicCollectionViewFlowLayout)?.itemsAligment , alignment != .fill else {
            return super.collectionView(collectionView, layout: collectionViewLayout, sizeForItemAt: indexPath)
        }
        
        if let action = self.actionForIndexPath(actionIndexPathFor(indexPath)), let actionData = action.data {
            let referenceWidth = min(collectionView.bounds.size.width, collectionView.bounds.size.height)
            let width = referenceWidth - (2 * settings.collectionView.lateralMargin) - collectionView.contentInset.left - collectionView.contentInset.right
            return CGSize(width: width, height: cellSpec.height(actionData))
        }
        return CGSize.zero
    }

    // MARK: - Overrides

    open override func dismiss() {
        dismiss(nil)
    }

    open override func dismiss(_ completion: (() -> ())?) {
        animator.addBehavior(gravityBehavior)

        UIView.animate(withDuration: settings.animation.dismiss.duration, animations: { [weak self] in
            self?.backgroundView.alpha = 0.0
        })

        presentingViewController?.dismiss(animated: true, completion: completion)
    }

    open override func dismissView(_ presentedView: UIView, presentingView: UIView, animationDuration: Double, completion: ((_ completed: Bool) -> Void)?) {
        onWillDismissView()

        UIView.animate(withDuration: animationDuration,
            animations: { [weak self] in
                presentingView.transform = CGAffineTransform.identity
                self?.performCustomDismissingAnimation(presentedView, presentingView: presentingView)
            },
            completion: { [weak self] finished in
                self?.onDidDismissView()
                completion?(finished)
            })
    }

    open override func onWillPresentView() {
        backgroundView.frame = view.bounds
        backgroundView.alpha = 0.0
        
        self.backgroundView.alpha = 1.0
        self.view.setNeedsLayout()
        self.view.layoutIfNeeded()
    }
    
    open override func performCustomDismissingAnimation(_ presentedView: UIView, presentingView: UIView) {
        // Nothing to do in this case
    }

}
