//
//  PVCheatsTableViewCell.swift
//  Provenance
//

import PVLibrary
import PVSupport
import RealmSwift
import UIKit

private let LabelHeight: CGFloat = 20.0

final class PVCheatsTableViewCell: UITableViewCell {
    public weak var delegate: PVCheatsViewControllerDelegate?

    public var cheat: PVCheats!
    
    @IBOutlet public var
        enableSwitch: UISwitch!
    @IBOutlet public var typeText: UILabel!
    @IBOutlet public var codeText: UILabel!
    
    @IBAction func toggleSwitch(_ sender: Any) {
        let realm = try! Realm()
        realm.beginWrite();
        cheat.enabled = enableSwitch.isOn;
        try! realm.commitWrite();
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

    
}
