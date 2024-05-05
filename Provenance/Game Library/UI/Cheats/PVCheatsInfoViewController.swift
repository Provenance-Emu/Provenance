//
//  PVCheatsInfoViewController.swift
//  Provenance
//

import PVLibrary
import PVSupport
import RealmSwift
import UIKit

final class PVCheatsInfoViewController: UIViewController, UITextFieldDelegate {
    weak var delegate: PVCheatsViewController?

    var mustRefreshDataSource: Bool = false

    public var codeTypeText:String = "";
    public var codeTypeButtons:[MenuButton] = [];
    @IBOutlet public var typeText: UITextField!
    #if os(iOS)
    @IBOutlet public var codeText: UITextView!
    #endif
    #if os(tvOS)
    @IBOutlet var saveButton: UIButton!
    @IBOutlet public var codeTextField: UITextField!
    var isEditingType: Bool!
    #endif
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
        #if os(tvOS)
        isEditingType=true
        #endif
        updateLabels()
        addCodeTypes()
    }

    #if os(tvOS)
    @IBAction func typeEditingBegin(_ sender: Any) {
        isEditingType=true
    }
    @IBAction func typeEditingFinished(_ sender: Any) {
        isEditingType=false
    }

    @IBAction func codeEditingBegin(_ sender: Any) {
        isEditingType=false
    }

    // MARK: - UITextField Delegates
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // Allow all letters to support encrypted cheat codes
        if textField == codeTextField {
            let allowedCharacters = CharacterSet(charactersIn:"-0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz ")
            let characterSet = CharacterSet(charactersIn: string)
            return allowedCharacters.isSuperset(of: characterSet)
        }
        if textField == typeText {
            let allowedCharacters = CharacterSet(charactersIn:"-012345678ABCDEFGHIJKLMNOPQRSTUVWXYZ!@#$%^&*()_+=`~][}{|'abcdefghijklmnopqrstuvwxyz ")
            let characterSet = CharacterSet(charactersIn: string)
            return allowedCharacters.isSuperset(of: characterSet)
        }
        return true
    }
    #endif

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
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
        #if os(tvOS)
        codeTextField.delegate=self
        #endif
        typeText?.placeholder = "e.g. Money"
        guard let saveState = saveState else {
            #if os(iOS)
            typeText.text=""
            codeText.text=""
            #endif
            #if os(tvOS)
            typeText.text=""
            codeTextField.text=""
            #endif
            return
        }

        #if os(iOS)
        typeText.text=saveState.type
        codeText.text=saveState.code
        #endif
        #if os(tvOS)
        typeText.text=saveState.type
        codeTextField.text=saveState.code
        #endif

        title = "\(saveState.game.title) : Cheat Codes)"

    }

    @IBAction func saveButtonTapped(_ sender: Any) {
        #if os(iOS)
        if !codeText.text.isEmpty {
            play()
        }
        #endif
        #if os(tvOS)
        let fieldValue=codeTextField.text ?? ""
        if !fieldValue.isEmpty {
            play()
        }
        #endif
    }

    @IBAction func
        cancelButtonTapped(_ sender: Any) {
        cancel()
    }

    func play() {
        guard
            let delegate = delegate,
            let table:UITableView = delegate.view as? UITableView else {
            ELOG("Nil delegate")
            return
        }

        let cheatIndex:UInt8 = UInt8(table.numberOfRows(inSection:0))
        if typeText.text == "" {
            typeText.text="Cheat Code"
        }
        #if os(iOS)
        delegate.saveCheatCode(code: codeText.text ?? "nil",
            type: typeText.text!,
            codeType: codeTypeText,
            cheatIndex: cheatIndex,
            enabled: true)
        // go back to the previous view controller
        _ = self.navigationController?.popViewController(animated: true)
        #endif
        #if os(tvOS)
        let fieldValue = self.codeTextField.text ?? ""
        if !fieldValue.isEmpty {
            self.delegate?.saveCheatCode(
                code: fieldValue,
                type: typeText.text ?? "nil",
                codeType: codeTypeText,
                cheatIndex: cheatIndex,
                enabled: true)
        }
        // go back to the previous view controller
        _ = self.navigationController?.popViewController(animated: true)
        #endif

    }
    func cancel() {
        _ = navigationController?.popViewController(animated: true)
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
                ILOG("The object was deleted.")
            }
        })
    }

    @objc func codeTypeSelected(_ sender: UIButton) {
        guard let delegate = delegate else {
            ELOG("Nil delegate")
            return
        }

        let types = delegate.getCheatTypes();
        codeTypeText=String(describing:types[sender.tag])
        for button in codeTypeButtons {
            let codeTypeButton:UIButton = button
            if codeTypeButton.tag == sender.tag {
                codeTypeButton.setBackgroundImage(.pixel(ofColor: .provenanceBlue), for: .normal)
            } else {
                codeTypeButton.setBackgroundImage(.pixel(ofColor: .darkGray), for: .normal)
            }
        }
    }

    @objc func addCodeTypes() {
        guard let delegate = delegate else {
            ELOG("Nil delegate")
            return
        }

        let types = delegate.getCheatTypes();
        var typeIdx:Int = 0;
        var anchorObject = self.view!
        #if os(tvOS)
        let codeTextObj = self.codeTextField
        #else
        let codeTextObj = self.codeText;
        #endif
        if (types.count < 1) {
            return
        }
        codeTypeText=String(describing:types[0])
        for case let type as NSString in types {
            let codeTypeButton = MenuButton(type: UIButton.ButtonType.roundedRect)
            let title = String(describing: type)
            #if os(tvOS)
            let buttonHeight: CGFloat = 70
            codeTypeButton.addTarget(self, action: #selector(self.codeTypeSelected(_:)), for: .primaryActionTriggered)
            #else
            let buttonHeight: CGFloat = 50
            codeTypeButton.addTarget(self, action: #selector(self.codeTypeSelected(_:)), for: .touchUpInside)
            #endif
            codeTypeButton.setTitle(title, for: .normal)
            codeTypeButton.setTitleColor(.white, for: .normal)
            codeTypeButton.frame = CGRect(x: 0, y: 0, width: codeTextObj!.frame.width, height: buttonHeight)
            codeTypeButton.heightAnchor.constraint(equalToConstant: buttonHeight).isActive = true
            codeTypeButton.tintColor = .white
            codeTypeButton.tag = typeIdx;
            codeTypeButton.contentEdgeInsets =  UIEdgeInsets(top: 8, left: 30, bottom: 8, right: 30)
            self.view.addSubview(codeTypeButton)
            codeTypeButton.translatesAutoresizingMaskIntoConstraints = false
            codeTypeButton.contentHorizontalAlignment = .center
            codeTypeButton.leadingAnchor.constraint(equalTo: codeTextObj!.leadingAnchor, constant: 0).isActive = true
            codeTypeButton.trailingAnchor.constraint(equalTo: codeTextObj!.trailingAnchor, constant: 0).isActive = true
            if (typeIdx == 0) {
                codeTypeButton.setBackgroundImage(.pixel(ofColor: .provenanceBlue), for: .normal)
                codeTypeButton.topAnchor.constraint(equalTo: codeTextObj!.bottomAnchor, constant: 10).isActive = true
                codeTypeButton.bottomAnchor.constraint(equalTo: codeTextObj!.bottomAnchor, constant: buttonHeight + 5).isActive = true
            } else {
                codeTypeButton.setBackgroundImage(.pixel(ofColor: .darkGray), for: .normal)
                codeTypeButton.topAnchor.constraint(equalTo: anchorObject.bottomAnchor, constant: 10).isActive = true
                codeTypeButton.bottomAnchor.constraint(equalTo: anchorObject.bottomAnchor, constant: buttonHeight + 5).isActive = true
            }
            codeTypeButton.isUserInteractionEnabled = true
            codeTypeButton.isEnabled = true
            codeTypeButton.isHighlighted = false
            codeTypeButton.isSelected = false
            anchorObject=codeTypeButton
            typeIdx+=1;
            codeTypeButtons.append(codeTypeButton)
        }
        #if os(tvOS)
        saveButton.topAnchor.constraint(equalTo: anchorObject.bottomAnchor, constant: 20).isActive = true
        #endif
    }
}

extension UIImage {
  public static func pixel(ofColor color: UIColor) -> UIImage {
    let pixel = CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0)

    UIGraphicsBeginImageContext(pixel.size)
    defer { UIGraphicsEndImageContext() }

    guard let context = UIGraphicsGetCurrentContext() else { return UIImage() }

    context.setFillColor(color.cgColor)
    context.fill(pixel)

    return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
  }
}
