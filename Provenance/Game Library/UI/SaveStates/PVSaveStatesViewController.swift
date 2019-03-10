//
//  PVSaveStatesViewController.swift
//  Provenance
//
//  Created by James Addyman on 30/03/2018.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import PVLibrary
import PVSupport
import Realm
import RealmSwift
import RxCocoa
import RxRealm
import RxSwift
import UIKit

protocol PVSaveStatesViewControllerDelegate: class {
    func saveStatesViewControllerDone(_ saveStatesViewController: PVSaveStatesViewController)
    func saveStatesViewControllerCreateNewState(_ saveStatesViewController: PVSaveStatesViewController, completion: @escaping SaveCompletion)
    func saveStatesViewControllerOverwriteState(_ saveStatesViewController: PVSaveStatesViewController, state: PVSaveState, completion: @escaping SaveCompletion)
    // TODO: This should either throw or have a callback as well
    func saveStatesViewController(_ saveStatesViewController: PVSaveStatesViewController, load state: PVSaveState)
}

struct SaveSection {
    let title: String
    let saves: Results<PVSaveState>
}

final class PVSaveStatesViewController: UICollectionViewController {
    private var autoSaveStatesObserverToken: NotificationToken!
    private var quickSaveStatesObserverToken: NotificationToken!
    private var manualSaveStatesObserverToken: NotificationToken!

    weak var delegate: PVSaveStatesViewControllerDelegate?

    var saveStates: LinkingObjects<PVSaveState>!
    var screenshot: UIImage?

    var coreID: String?

    private var autoSaves: Results<PVSaveState>!
    private var quickSaves: Results<PVSaveState>!
    private var manualSaves: Results<PVSaveState>!

    deinit {
        autoSaveStatesObserverToken.invalidate()
        autoSaveStatesObserverToken = nil
        quickSaveStatesObserverToken?.invalidate()
        quickSaveStatesObserverToken = nil
        manualSaveStatesObserverToken = nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        #if os(iOS)
            title = "Save States"
        #endif
        #if os(tvOS)
            collectionView?.register(UINib(nibName: "PVSaveStateCollectionViewCell~tvOS", bundle: nil), forCellWithReuseIdentifier: "SaveStateView")
        #else
            collectionView?.register(UINib(nibName: "PVSaveStateCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "SaveStateView")
        #endif

        let allSaves: Results<PVSaveState>
        if let coreID = coreID {
            let filter: String = "core.identifier == \"" + coreID + "\""
            allSaves = saveStates.filter(filter).sorted(byKeyPath: "date", ascending: false)
        } else {
            allSaves = saveStates.sorted(byKeyPath: "date", ascending: false)
        }

        manualSaves = allSaves.filter("saveTypeRawValue == '\(SaveType.manual.rawValue)'")
        autoSaves = allSaves.filter("saveTypeRawValue == '\(SaveType.auto.rawValue)'")
        quickSaves = allSaves.filter("saveTypeRawValue == '\(SaveType.quick.rawValue)'")

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
            self.handleRealmCollectionChange(changes: changes, collectionView: self.collectionView, section: 0)
        }
        
        quickSaveStatesObserverToken = quickSaves.observe { [weak self] (changes: RealmCollectionChange) in
            guard let `self` = self else { return }
            self.handleRealmCollectionChange(changes: changes, collectionView: self.collectionView, section: 1)
        }

        manualSaveStatesObserverToken = manualSaves.observe { [weak self] (changes: RealmCollectionChange) in
            guard let `self` = self else { return }
            self.handleRealmCollectionChange(changes: changes, collectionView: self.collectionView, section: 2)
        }
        
        let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(self.longPressRecognized(_:)))
        collectionView?.addGestureRecognizer(longPressRecognizer)
    }
    
    func handleRealmCollectionChange(changes: RealmCollectionChange<Results<PVSaveState>>, collectionView: UICollectionView, section: Int) {
        switch changes {
        case .initial:
            self.collectionView?.reloadData()
        case .update(_, let deletions, let insertions, _):
            guard deletions.count > 0 || insertions.count > 0 else {
                return
            }
            let fromItem = { (item: Int) -> IndexPath in
                return IndexPath(item: item, section: section)
            }
            self.collectionView?.performBatchUpdates({
                self.collectionView?.deleteItems(at: deletions.map(fromItem))
                self.collectionView?.insertItems(at: insertions.map(fromItem))
            }, completion: nil)
        case .error(let error):
            ELOG("Error updating save states: " + error.localizedDescription)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if let emulatorViewController = presentingViewController as? PVEmulatorViewController {
            emulatorViewController.core.setPauseEmulation(false)
            emulatorViewController.isShowingMenu = false
            emulatorViewController.enableContorllerInput(false)
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
                state = quickSaves[indexPath.item]
            case 2:
                state = manualSaves[indexPath.item]
            default:
                break
            }

            guard let saveState = state else {
                ELOG("No save state at indexPath: \(indexPath)")
                return
            }

            let alert = UIAlertController(title: "Delete this save state?", message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Yes", style: .destructive) { [unowned self] _ in
                do {
                    try PVSaveState.delete(saveState)
                } catch {
                    self.presentError("Error deleting save state: \(error.localizedDescription)")
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
        delegate?.saveStatesViewControllerCreateNewState(self) { result in
            switch result {
            case .success:
                break
            case let .error(error):
                let reason = (error as NSError).localizedFailureReason ?? ""
                self.presentError("Error creating save state: \(error.localizedDescription) \(reason)")
            }
        }
    }

    func showSaveStateOptions(saveState: PVSaveState) {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Load", style: .default, handler: { (_: UIAlertAction) in
            self.delegate?.saveStatesViewController(self, load: saveState)
        }))
        alert.addAction(UIAlertAction(title: "Save & Overwrite", style: .default, handler: { (_: UIAlertAction) in
            self.delegate?.saveStatesViewControllerOverwriteState(self, state: saveState) { result in
                switch result {
                case .success:
                    break
                case let .error(error):
                    self.presentError("Error overwriting save state: \(error.localizedDescription)")
                }
            }
        }))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { (_: UIAlertAction) in
            do {
                try PVSaveState.delete(saveState)
            } catch {
                self.presentError("Error deleting save state: \(error.localizedDescription)")
            }
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(alert, animated: true)
    }

    override func numberOfSections(in _: UICollectionView) -> Int {
        return 3
    }

    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let reusableView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "SaveStateHeader", for: indexPath) as! PVSaveStateHeaderView
        switch indexPath.section {
        case 0:
            reusableView.label.text = "Auto Save"
        case 1:
            reusableView.label.text = "Quick Save"
        case 2:
            reusableView.label.text = "Save States"
        default:
            break
        }

        return reusableView
    }

    override func collectionView(_: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch section {
        case 0:
            return autoSaves.count
        case 1:
            return quickSaves.count
        case 2:
            return manualSaves.count
        default:
            return 0
        }
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "SaveStateView", for: indexPath) as! PVSaveStateCollectionViewCell
        var saveState: PVSaveState?
        switch indexPath.section {
        case 0:
            saveState = autoSaves[indexPath.item]
        case 1:
            saveState = quickSaves[indexPath.item]
        case 2:
            saveState = manualSaves[indexPath.item]
        default:
            break
        }

        cell.saveState = saveState

        return cell
    }

    override func collectionView(_: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch indexPath.section {
        case 0:
            let saveState = autoSaves[indexPath.item]
            delegate?.saveStatesViewController(self, load: saveState)
        case 1:
            let saveState = quickSaves[indexPath.item]
            delegate?.saveStatesViewController(self, load: saveState)
        case 2:
            var saveState: PVSaveState?
            saveState = manualSaves[indexPath.item]
            guard let state = saveState else {
                ELOG("No save state at indexPath: \(indexPath)")
                return
            }
            showSaveStateOptions(saveState: state)
        default:
            break
        }
    }
}
