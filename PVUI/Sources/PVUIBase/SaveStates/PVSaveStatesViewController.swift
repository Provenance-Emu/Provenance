//
//  PVSaveStatesViewController.swift
//  Provenance
//
//  Created by James Addyman on 30/03/2018.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import PVLibrary
import PVSupport
import RealmSwift
import RxCocoa
import RxRealm
import RxSwift
import PVLogging
import PVRealm

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

public
struct SaveSection {
    let title: String
    let saves: Results<PVSaveState>
}

public
final class PVSaveStatesViewController: UICollectionViewController {
    private var autoSaveStatesObserverToken: NotificationToken!
    private var manualSaveStatesObserverToken: NotificationToken!
    
    weak var delegate: PVSaveStatesViewControllerDelegate?
    
    var saveStates: LinkingObjects<PVSaveState>!
    var screenshot: UIImage?
    
    var coreID: String?
    
    private var autoSaves: Results<PVSaveState>!
    private var manualSaves: Results<PVSaveState>!
    
    deinit {
        autoSaveStatesObserverToken.invalidate()
        autoSaveStatesObserverToken = nil
        manualSaveStatesObserverToken.invalidate()
        manualSaveStatesObserverToken = nil
    }
    
    @MainActor
    func refreshSaves() {
        var allSaves: Results<PVSaveState>
        if let coreID = coreID {
            let filter: String = "core.identifier == \"" + coreID + "\""
            allSaves = saveStates.filter(filter).sorted(byKeyPath: "date", ascending: false)
        } else {
            allSaves = saveStates.sorted(byKeyPath: "date", ascending: false)
        }
        autoSaves = allSaves.filter("isAutosave == true")
        manualSaves = allSaves.filter("isAutosave == false")
        var didDeleteSave: Bool = false
        allSaves.forEach { save in
            guard !save.isInvalidated else { return }
            let path = save.file.url.path
            if !FileManager.default.fileExists(atPath: path) {
                do {
                    try PVSaveState.delete(save)
                    didDeleteSave = true
                } catch {
                    ELOG("Error deleting save state: \(error.localizedDescription)")
                }
            }
        }
        if didDeleteSave {
            refreshSaves()
        } else {
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.collectionView?.reloadData()
            }
        }
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        self.refreshSaves()
        
#if os(iOS)
        title = "Save States"
#endif
#if os(tvOS)
        collectionView?.register(UINib(nibName: "PVSaveStateCollectionViewCell~tvOS", bundle: BundleLoader.module), forCellWithReuseIdentifier: "SaveStateView")
#else
        collectionView?.register(UINib(nibName: "PVSaveStateCollectionViewCell", bundle: BundleLoader.module), forCellWithReuseIdentifier: "SaveStateView")
#endif
        
        
        if screenshot == nil {
            navigationItem.rightBarButtonItem = nil
        }
        
        //
        //        let dataSource = RxCollectionViewRealmDataSource(sections: [
        //            RxRealmDataSourceSection<PVSaveState>(title: "Auto Saves",
        //                                                  cellIdentifier: "SaveStateView",
        //                                                  cellConfig: { (cellType, indexPath, saveState) in
        //
        //            },
        //                                                  items: AnyRealmCollection<PVSaveState>(autoSaves),
        //                                                  section: 0)
        //            ])
        //
        //        let dataSource = RxCollectionViewRealmDataSource<PVSaveState>(cellIdentifier: "SaveStateView", cellType: PVSaveStateCollectionViewCell.self) { cell, indexPath, saveState in
        //            cell.saveState = saveState
        //        }
        //
        //        Observable.collection(from: allSaves).map { results in
        //            return [
        //                SaveSection(title: "Auto Saves", saves: results.filter("isAutosave == true")),
        //                SaveSection(title: "User Saves", saves: results.filter("isAutosave == false"))
        //            ]
        //            }
        //            .map { sections in
        //                return sections.filter { section in
        //                    return section.saves.count > 0
        //                }
        //            }
        //            .bind(to: collectionView.rx.items(dataSource: dataSource))
        //            .disposed(by: disposeBag)
        //
        autoSaveStatesObserverToken = autoSaves.observe { [weak self] (changes: RealmCollectionChange) in
            guard let `self` = self else { return }
            switch changes {
            case .initial:
                self.collectionView?.reloadData()
            case .update(_, let deletions, _, _):
                guard !deletions.isEmpty else {
                    return
                }
                
                let fromItem = { (item: Int) -> IndexPath in
                    let section = 0
                    return IndexPath(item: item, section: section)
                }
                self.collectionView?.reloadData()
            case let .error(error):
                ELOG("Error updating save states: " + error.localizedDescription)
            }
        }
        
        manualSaveStatesObserverToken = manualSaves.observe { [weak self] (changes: RealmCollectionChange) in
            guard let `self` = self else { return }
            
            switch changes {
            case .initial:
                self.collectionView?.reloadData()
            case .update(_, let deletions, let insertions, _):
                guard !deletions.isEmpty || !insertions.isEmpty else {
                    return
                }
                let fromItem = { (item: Int) -> IndexPath in
                    let section = 1
                    return IndexPath(item: item, section: section)
                }
                self.collectionView?.reloadData()
            case let .error(error):
                ELOG("Error updating save states: " + error.localizedDescription)
            }
        }
        
        let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(longPressRecognized(_:)))
        collectionView?.addGestureRecognizer(longPressRecognizer)
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if let emulatorViewController = presentingViewController as? PVEmualatorControllerProtocol {
            emulatorViewController.core.setPauseEmulation(false)
            emulatorViewController.isShowingMenu = false
            emulatorViewController.enableControllerInput(false)
        }
    }
    
    @objc func longPressRecognized(_ recognizer: UILongPressGestureRecognizer) {
        switch recognizer.state {
        case .began:
            let point: CGPoint = recognizer.location(in: collectionView)
            var maybeIndexPath: IndexPath? = collectionView?.indexPathForItem(at: point)
            
#if os(tvOS)
            if maybeIndexPath == nil, let focusedView = UIScreen.main.focusedView as? UICollectionViewCell {
                maybeIndexPath = collectionView?.indexPath(for: focusedView)
            }
#endif
            guard let indexPath = maybeIndexPath else {
                ELOG("No index path at touch point")
                return
            }
            
            var state: PVSaveState?
            switch indexPath.section {
            case 0:
                state = autoSaves[indexPath.item]
            case 1:
                state = manualSaves[indexPath.item]
            default:
                break
            }
            
            guard let saveState = state else {
                ELOG("No save state at indexPath: \(indexPath)")
                return
            }
            
            let alert = UIAlertController(title: "Delete this save state?", message: nil, preferredStyle: .alert)
            alert.preferredContentSize = CGSize(width: 300, height: 150)
            alert.popoverPresentationController?.sourceView = collectionView?.cellForItem(at: indexPath)?.contentView
            alert.popoverPresentationController?.sourceRect = collectionView?.cellForItem(at: indexPath)?.contentView.bounds ?? UIScreen.main.bounds
            alert.addAction(UIAlertAction(title: "Yes", style: .destructive) { [weak self] _ in
                Task {
                    do {
                        try PVSaveState.delete(saveState)
                        self?.refreshSaves()
                    } catch {
                        NSLog("Error deleting save state: \(error.localizedDescription)")
                    }
                }
            })
            alert.addAction(UIAlertAction(title: "No", style: .cancel, handler: nil))
            present(alert, animated: true)
        default:
            break
        }
    }
    
    @IBAction func done(_: Any) {
        delegate?.saveStatesViewControllerDone(self)
    }
    
    @IBAction func newSaveState(_: Any) {
        Task {
            do {
                guard let delegate = delegate else {
                    WLOG("nil delegate")
                    return
                }
                let result = try await delegate.saveStatesViewControllerCreateNewState(self)
                
                if !result {
                    self.presentError("Error creating save state: Uknown reason", source: self.view)
                }
            } catch {
                let reason = (error as NSError).localizedFailureReason ?? error.localizedDescription
                self.presentError("Error creating save state: \(error.localizedDescription) \(reason)", source: self.view)
            }
        }
    }
    
    func showSaveStateOptions(saveState: PVSaveState, source: UIView?) {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.preferredContentSize = CGSize(width: 300, height: 150)
        alert.popoverPresentationController?.sourceView = source
        alert.popoverPresentationController?.sourceRect = source?.bounds ?? UIScreen.main.bounds
        alert.addAction(UIAlertAction(title: "Load", style: .default, handler: { (_: UIAlertAction) in
            self.delegate?.saveStatesViewController(self, load: saveState)
        }))
        alert.addAction(UIAlertAction(title: "Save & Overwrite", style: .default, handler: { [weak self] (_: UIAlertAction) in
            guard let self = self, let delegate = self.delegate else {
                WLOG("Nil delegate")
                return
            }
            Task {
                do {
                    
                    let result = try await delegate.saveStatesViewControllerOverwriteState(self, state: saveState)
                    
                    if !result {
                        self.presentError("Error overwriting save state: Uknown reason", source: self.view)
                    }
                } catch {
                    ELOG("Error overwriting save state: \(error.localizedDescription)")
                    self.presentError("Error overwriting save state: \(error.localizedDescription)", source: self.view)
                }
            }
        }))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { [weak self] (_: UIAlertAction) in
            guard let self = self else {
                WLOG("Nil self")
                return
            }
            Task { [weak self] in
                do {
                    try PVSaveState.delete(saveState)
                    self?.refreshSaves()
                } catch {
                    ELOG("Error deleting save state: \(error.localizedDescription)")
                    self?.presentError("Error deleting save state: \(error.localizedDescription)", source: self!.view)
                }
            }
        }))
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel"), style: .cancel, handler: nil))
        present(alert, animated: true)
    }
    
    public override func numberOfSections(in _: UICollectionView) -> Int {
        return 2
    }
    
    public override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let reusableView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "SaveStateHeader", for: indexPath) as! PVSaveStateHeaderView
        switch indexPath.section {
        case 0:
            reusableView.label.text = "Auto Save"
        case 1:
            reusableView.label.text = "Save States"
        default:
            break
        }
        
        return reusableView
    }
    
    public override func collectionView(_: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch section {
        case 0:
            return autoSaves.count
        case 1:
            return manualSaves.count
        default:
            return 0
        }
    }
    
    public override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "SaveStateView", for: indexPath) as! PVSaveStateCollectionViewCell
        
#if os(tvOS)
        cell.saveStateView = true
#endif
        
        var saveState: PVSaveState?
        switch indexPath.section {
        case 0:
            saveState = autoSaves[indexPath.item]
        case 1:
            saveState = manualSaves[indexPath.item]
        default:
            break
        }
        
        cell.saveState = saveState
        
        return cell
    }
    
    public override func collectionView(_: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch indexPath.section {
        case 0:
            var saveState: PVSaveState?
            saveState = autoSaves[indexPath.item]
            guard let state = saveState else {
                ELOG("No save state at indexPath: \(indexPath)")
                return
            }
            delegate?.saveStatesViewController(self, load: state)
        case 1:
            var saveState: PVSaveState?
            saveState = manualSaves[indexPath.item]
            guard let state = saveState else {
                ELOG("No save state at indexPath: \(indexPath)")
                return
            }
            showSaveStateOptions(saveState: state, source: collectionView?.cellForItem(at: indexPath)?.contentView)
        default:
            break
        }
    }
}
