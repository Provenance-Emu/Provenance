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

    #if os(iOS)
    @IBOutlet public var enableSwitch: UISwitch!
    #endif

    #if os(tvOS)
    @IBOutlet public var enabledText: UILabel!
    #endif

    @IBOutlet public var codeText: UILabel!
    @IBOutlet public var typeText: UILabel!

    @IBAction func toggleSwitch(_ sender: Any) {
        #if os(iOS)
        toggle(enabled: enableSwitch.isOn)
        #endif
    }

    func toggle(enabled:Bool) {
        let table:UITableView = self.superview as! UITableView;
        let cheatIndex:UInt8  = UInt8(table.indexPath(for: self)!.row);
        let realm = try! Realm()
        realm.beginWrite()
        cheat.enabled = enabled
        try! realm.commitWrite()
        delegate?.cheatsViewControllerUpdateState(self, cheat: cheat, cheatIndex: cheatIndex) { result
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
