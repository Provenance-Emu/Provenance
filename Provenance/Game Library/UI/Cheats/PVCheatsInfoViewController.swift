//
//  PVCheatsInfoViewController.swift
//  Provenance
//

import PVLibrary
import PVSupport
import RealmSwift
import UIKit

final class PVCheatsInfoViewController: UIViewController {
    weak var delegate: PVCheatsViewController? = nil
    
    var mustRefreshDataSource: Bool = false

    @IBOutlet public var typeText: UITextField!
    @IBOutlet public var codeText: UITextView!
    
    var saveState: PVCheats? {
        didSet {
            assert(saveState != nil, "Set a nil game")

            if saveState != oldValue {
                registerForChange()

                if isViewLoaded {
                    updateLabels()
                }
            }
        }
    }

    deinit {
        token?.invalidate()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        updateLabels()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateLabels()
    }

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .short
        return df
    }()

    private static let timeFormatter: DateFormatter = {
        let tf = DateFormatter()
        tf.timeStyle = .short
        return tf
    }()

    func updateLabels() {
        guard let saveState = saveState else {
            typeText.text="";
            codeText.text="";
            return
        }

        typeText.text=saveState.type;
        codeText.text=saveState.code;

        title = "\(saveState.game.title) : Cheat Codes)"

    }

    @IBAction func
        saveButtonTapped(_ sender: Any) {
        play(sender)
    }

    @IBAction func
        cancelButtonTapped(_ sender: Any) {
        cancel(sender)
    }

    func play(_ sender: Any) {
        delegate?.saveCheatCode(code: codeText.text!,
            type: typeText.text!,
            enabled: true)
    
        // go back to the previous view controller
        _ = self.navigationController?.popViewController(animated: true)
    }
    func cancel(_ sender: Any) {
        _ = navigationController?.popViewController(animated: true);
    }

    var token: NotificationToken?
    func registerForChange() {
        token?.invalidate()
        token = saveState?.observe({ change in
            switch change {
            case let .change(_, properties):
                if !properties.isEmpty, self.isViewLoaded {
                    DispatchQueue.main.async {
                        self.updateLabels()
                    }
                }
            case let .error(error):
                ELOG("An error occurred: \(error)")
            case .deleted:
                print("The object was deleted.")
            }
        })
    }
}

extension PVCheatsInfoViewController {
    // Buttons that shw up under thie VC when it's in a push/pop preview display mode
    override var previewActionItems: [UIPreviewActionItem] {
        let playAction = UIPreviewAction(title: "Play", style: .default) { [unowned self] _, _ in
            if let view = self.view {
                self.play(view)
            } else {
                assertionFailure("Nil view")
            }
        }

        let deleteAction = UIPreviewAction(title: "Delete", style: .destructive) { [unowned self] _, _ in
            let alert = UIAlertController(title: "Delete save state", message: "Are you sure?", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Yes", style: .destructive, handler: { (_: UIAlertAction) -> Void in
                if let saveState = self.saveState {
                    do {
                        try PVCheats.delete(saveState)
                    } catch {
                        self.presentError("Error deleting save state: " + error.localizedDescription)
                    }
                } else {
                    ELOG("Save state var was nil, can't delete")
                }
            }))
            alert.addAction(UIAlertAction(title: "No", style: .cancel, handler: nil))

            (UIApplication.shared.delegate?.window??.rootViewController ?? self).present(alert, animated: true)
        }

        return [playAction, deleteAction]
    }
}
