//
//  PVCheatsViewController.swift
//  Provenance
//

import PVLibrary
import PVSupport
import Realm
import RealmSwift
import RxCocoa
import RxRealm
import RxSwift
import UIKit

protocol PVCheatsViewControllerDelegate: AnyObject {
    func cheatsViewControllerDone(_ cheatsViewController: PVCheatsViewController)
    func cheatsViewControllerCreateNewState(_ cheatsViewController: PVCheatsViewController,
        code: String,
        type: String,
        codeType: String,
        cheatIndex: UInt8,
        enabled: Bool,
        completion: @escaping CheatsCompletion)
    func cheatsViewControllerUpdateState(_:Any,
         cheat: PVCheats,
         cheatIndex: UInt8,
         completion: @escaping CheatsCompletion)
    func cheatsViewController(_ cheatsViewController: PVCheatsViewController, load state: PVCheats)
    func getCheatTypes() -> NSArray
}

struct CheatsSection {
    let title: String
    let saves: Results<PVCheats>
}

final class PVCheatsViewController: UITableViewController {
    weak var delegate: PVCheatsViewControllerDelegate?

    var cheats: LinkingObjects<PVCheats>!
    var screenshot: UIImage?

    var coreID: String?

    private var allCheats: Results<PVCheats>?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Cheat Codes"
        var isFirstLoad: Bool=true
        if let emulatorViewController = presentingViewController as? PVEmulatorViewController {
            isFirstLoad=emulatorViewController.getIsFirstLoad()
        }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let coreID = self.coreID {
                let filter: String = "core.identifier == \"" + coreID + "\""
                self.allCheats = self.cheats.filter(filter).sorted(byKeyPath: "date", ascending: true)
            } else {
                self.allCheats = self.cheats.sorted(byKeyPath: "date", ascending: true)
            }
            var cheatIndex:UInt8=0;
            for cheat in self.allCheats! {
                DLOG("Cheat Found \(String(describing: cheat.code)) \(String(describing: cheat.type))")
                // start disabled to prevent bad cheat code from crashing the game all the time
                if (isFirstLoad) {
                    let realm = try! Realm()
                    realm.beginWrite()
                    cheat.enabled = false
                    try! realm.commitWrite()
                }
                self.delegate?.cheatsViewControllerUpdateState(self, cheat: cheat, cheatIndex: cheatIndex) { result
                    in
                    switch result {
                    case .success:
                        break
                    case let .error(error):
                        let reason = (error as NSError).localizedFailureReason ?? ""
                        ELOG("Error Updating CheatCode: \(error.localizedDescription) \(reason)")
                    }
                }
                cheatIndex+=1
            }
            let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(self.longPressRecognized(_:)))
            self.tableView.dataSource = self
            self.tableView.delegate = self
            self.tableView?.addGestureRecognizer(longPressRecognizer)
            self.tableView.reloadData()
            self.tableView.layoutIfNeeded()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if navigationController?.viewControllers.count == 1,
            let emulatorViewController = presentingViewController as? PVEmulatorViewController {
                emulatorViewController.core.setPauseEmulation(false)
                emulatorViewController.isShowingMenu = false
                emulatorViewController.enableControllerInput(false)
                emulatorViewController.setIsFirstLoad(isFirstLoad: false)
        }
    }

    @objc func longPressRecognized(_ recognizer: UILongPressGestureRecognizer) {
        switch recognizer.state {
        case .began:
            let point: CGPoint = recognizer.location(in: tableView)
            var maybeIndexPath: IndexPath? = tableView?.indexPathForRow(at: point)

            #if os(tvOS)
                if maybeIndexPath == nil, let focusedView = UIScreen.main.focusedView as? UITableViewCell {
                    maybeIndexPath = tableView?.indexPath(for: focusedView)
                }
            #endif
            guard let indexPath = maybeIndexPath else {
                ELOG("No index path at touch point")
                return
            }

            let state: PVCheats? = allCheats?[indexPath.item]

            guard let saveState = state else {
                ELOG("No cheat code at indexPath: \(indexPath)")
                return
            }

            let alert = UIAlertController(title: "Delete this Cheat Code?", message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Yes", style: .destructive) { [unowned self] _ in
                do {
                    try  PVCheats.delete(saveState)

                        self.tableView.reloadData()
                        self.tableView.layoutIfNeeded()
                } catch {
                    self.presentError("Error deleting CheatCode: \(error.localizedDescription)")
                }
            })
            alert.addAction(UIAlertAction(title: "No", style: .cancel, handler: nil))

            present(alert, animated: true)
        default:
            break
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
            if segue.identifier == "cheatCodeInfo" {
                DLOG("Add Cheat Code")
                let secondViewController = segue.destination as! PVCheatsInfoViewController
                secondViewController.delegate = self
            }
        }

    @IBAction func done(_: Any) {
        delegate?.cheatsViewControllerDone(self)
    }

    func saveCheatCode(code: String, type: String, codeType: String, cheatIndex: UInt8, enabled: Bool) {
        ILOG("SaveCheatCode \(code) \(type)")
        delegate?.cheatsViewControllerCreateNewState(self, code: code, type: type, codeType: codeType, cheatIndex: cheatIndex, enabled: enabled) {
            result in
                switch result {
                case .success:
                    self.tableView.reloadData()
                    self.tableView.layoutIfNeeded()

                    break
                case let .error(error):
                    let reason = (error as NSError).localizedFailureReason ?? ""
                    self.presentError("Error creating CheatCode: \(error.localizedDescription) \(reason)")
                }
        }
    }

    func getCheatTypes() -> NSArray {
        return delegate!.getCheatTypes();
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return allCheats?.count ?? 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "cheatCodeCell", for: indexPath) as! PVCheatsTableViewCell
		cell.delegate=delegate
		guard let cheat:PVCheats = allCheats?[indexPath.row] else {
			ELOG("Nil allCheats")
			return cell
		}
        var cheatType = cheat.type ?? ""
        if cheatType.contains("-~-") {
            let types = cheatType.components(separatedBy: "-~-")
            cheatType = types[0]
        }
		cell.codeText.text=cheat.code
		cell.typeText.text=cheatType
#if os(iOS)
		cell.enableSwitch.isOn=cheat.enabled
#endif
#if os(tvOS)
		cell.enabledText.text=cheat.enabled ? "Enabled" : "Disabled"
#endif
		cell.cheat=cheat
		return cell
	}

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
            return CGFloat(80)
    }

    #if os(tvOS)
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		guard let allCheats = allCheats else {
			ELOG("Nil allcheats")
			return
		}
        let cheat:PVCheats = allCheats[indexPath.row]

        let realm = try! Realm()
        realm.beginWrite()
        cheat.enabled = !(cheat.enabled)
        try! realm.commitWrite()
        delegate?.cheatsViewControllerUpdateState(self, cheat: cheat, cheatIndex:UInt8(indexPath.row)) { result
            in
            switch result {
            case .success:
                break
            case let .error(error):
                let realm = try! Realm()
                realm.beginWrite()
                cheat.enabled = !(cheat.enabled)
                try! realm.commitWrite()
                let reason = (error as NSError).localizedFailureReason ?? ""
                ELOG("Error Updating CheatCode: \(error.localizedDescription) \(reason)")
            }
        }
        self.tableView.reloadData()
        self.tableView.layoutIfNeeded()
    }
    #endif
}
