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
        enabled: Bool,
        completion: @escaping CheatsCompletion)
    func cheatsViewControllerUpdateState(_:Any,
         cheat: PVCheats,
         completion: @escaping CheatsCompletion)
    func cheatsViewController(_ cheatsViewController: PVCheatsViewController, load state: PVCheats)
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

    private var enabledCheats: Results<PVCheats>!
    private var disabledCheats: Results<PVCheats>!
    private var allCheats: Results<PVCheats>!

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Cheat Codes"

        if let coreID = coreID {
            let filter: String = "core.identifier == \"" + coreID + "\""
            allCheats = cheats.filter(filter).sorted(byKeyPath: "date", ascending: false)
        } else {
            allCheats = cheats.sorted(byKeyPath: "date", ascending: false)
        }

        var isFirstLoad: Bool=true

        if let emulatorViewController = presentingViewController as? PVEmulatorViewController {
            isFirstLoad=emulatorViewController.getIsFirstLoad()
        }

        for cheat in allCheats {
            NSLog("Cheat Found \(String(describing: cheat.code)) \(String(describing: cheat.type))")
            // start disabled to prevent bad cheat code from crashing the game all the time
            if (isFirstLoad) {
                let realm = try! Realm()
                realm.beginWrite()
                cheat.enabled = false
                try! realm.commitWrite()
            }
            delegate?.cheatsViewControllerUpdateState(self, cheat: cheat) { result
                in
                switch result {
                case .success:
                    break
                case let .error(error):
                    let reason = (error as NSError).localizedFailureReason ?? ""
                    NSLog("Error Updating CheatCode: \(error.localizedDescription) \(reason)")
                }
            }
        }

        let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(longPressRecognized(_:)))
        tableView.dataSource = self
        tableView.delegate = self

        tableView?.addGestureRecognizer(longPressRecognizer)

        self.tableView.reloadData()
        self.tableView.layoutIfNeeded()
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

            let state: PVCheats? = allCheats[indexPath.item]

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
                NSLog("Add Cheat Code")
                let secondViewController = segue.destination as! PVCheatsInfoViewController
                secondViewController.delegate = self
            }
        }

    @IBAction func done(_: Any) {
        delegate?.cheatsViewControllerDone(self)
    }

    func saveCheatCode(code: String, type: String, enabled: Bool) {
        NSLog("SaveCheatCode \(code) \(type)")
        delegate?.cheatsViewControllerCreateNewState(self, code: code, type: type, enabled: enabled) { result in
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

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return allCheats.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cheatCodeCell", for: indexPath) as! PVCheatsTableViewCell
        let cheat:PVCheats = allCheats[indexPath.row]
        cell.codeText.text=cheat.code
        cell.typeText.text=cheat.type
        #if os(iOS)
        cell.enableSwitch.isOn=cheat.enabled
        #endif
        #if os(tvOS)
        cell.enabledText.text=cheat.enabled ? "Enabled" : "Disabled"
        #endif
        cell.delegate=delegate
        cell.cheat=cheat

        return cell
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
            return CGFloat(80)
    }

    #if os(tvOS)
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cheat:PVCheats = allCheats[indexPath.row]

        let realm = try! Realm()
        realm.beginWrite()
        cheat.enabled = !(cheat.enabled)
        try! realm.commitWrite()
        delegate?.cheatsViewControllerUpdateState(self, cheat: cheat) { result
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
                NSLog("Error Updating CheatCode: \(error.localizedDescription) \(reason)")
            }

        }
        self.tableView.reloadData()
        self.tableView.layoutIfNeeded()
    }
    #endif
}
