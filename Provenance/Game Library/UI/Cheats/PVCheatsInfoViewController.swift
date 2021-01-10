//
//  PVCheatsInfoViewController.swift
//  Provenance
//

import PVLibrary
import PVSupport
import RealmSwift
import UIKit

final class PVCheatsInfoViewController: UIViewController, UITextFieldDelegate {
    weak var delegate: PVCheatsViewController? = nil
    
    var mustRefreshDataSource: Bool = false

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
    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard let key = presses.first?.key else { return }
        NSLog("Receive Ended \(key)")
        if (!isEditingType) {
            let fieldValue=codeTextField.text ?? ""
            switch key.keyCode {
                case .keyboard1:
                    codeTextField.text=fieldValue + "1"
                case .keyboard2:
                    codeTextField.text=fieldValue + "2"
                case .keyboard3:
                    codeTextField.text=fieldValue + "3"
                case .keyboard4:
                    codeTextField.text=fieldValue + "4"
                case .keyboard5:
                    codeTextField.text=fieldValue + "5"
                case .keyboard6:
                    codeTextField.text=fieldValue + "6"
                case .keyboard7:
                    codeTextField.text=fieldValue + "7"
                case .keyboard8:
                    codeTextField.text=fieldValue + "8"
                case .keyboard9:
                    codeTextField.text=fieldValue + "9"
                case .keyboard0:
                    codeTextField.text=fieldValue + "0"
                case .keyboardA:
                    codeTextField.text=fieldValue + "A"
                case .keyboardB:
                    codeTextField.text=fieldValue + "B"
                case .keyboardC:
                    codeTextField.text=fieldValue + "C"
                case .keyboardD:
                    codeTextField.text=fieldValue + "D"
                case .keyboardE:
                    codeTextField.text=fieldValue + "E"
                case .keyboardF:
                    codeTextField.text=fieldValue + "F"
                case .keyboardSpacebar:
                    codeTextField.text=fieldValue + " "
                case .keyboardHyphen:
                    codeTextField.text=fieldValue + "-"
                case .keyboardDeleteOrBackspace:
                    codeTextField.text=String(fieldValue.dropLast())
                case .keyboardReturnOrEnter:
                    play()
                case .keyboardDownArrow:
                    saveButton.becomeFirstResponder()
            default:
                    super.pressesEnded(presses, with: event)
            }
        } else {
            let fieldValue=self.typeText.text ?? ""
            switch key.keyCode {
                case .keyboardDeleteOrBackspace:
                    typeText.text=String(fieldValue.dropLast())
                case .keyboardReturnOrEnter:
                    codeTextField.becomeFirstResponder()
                case .keyboardDownArrow:
                    codeTextField.becomeFirstResponder()
                default:
                    typeText.text=fieldValue + key.characters
            }
            
        }
    }
    //MARK - UITextField Delegates
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        //For mobile numer validation
        if textField == codeTextField {
            let allowedCharacters = CharacterSet(charactersIn:"-0123456789ABCDEFabcdef ")
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
        #if os(tvOS)
        codeTextField.delegate=self
        #endif
        typeText?.placeholder = "e.g. Money"
        guard let saveState = saveState else {
            #if os(iOS)
            typeText.text="";
            codeText.text="";
            #endif
            #if os(tvOS)
            codeTextField.text="";
            #endif
            return
        }

        #if os(iOS)
        typeText.text=saveState.type;
        codeText.text=saveState.code;
        #endif
        #if os(tvOS)
        codeTextField.text=saveState.code;
        #endif
        

        title = "\(saveState.game.title) : Cheat Codes)"

    }

    @IBAction func
        saveButtonTapped(_ sender: Any) {
        #if os(iOS)
        if (codeText.text.count > 0) {
            play()
        }
        #endif
        #if os(tvOS)
        let fieldValue=codeTextField.text ?? ""
        if (fieldValue.count > 0) {
            play()
        }
        #endif
        
    }

    @IBAction func
        cancelButtonTapped(_ sender: Any) {
        cancel()
    }

    func play() {
        #if os(iOS)
        delegate?.saveCheatCode(code: codeText.text!,
            type: typeText.text!,
            enabled: true)
        // go back to the previous view controller
        _ = self.navigationController?.popViewController(animated: true)
        #endif
        #if os(tvOS)
        let fieldValue = self.codeTextField.text ?? ""
        if (fieldValue.count > 0) {
            self.delegate?.saveCheatCode(
                code: fieldValue,
                type: typeText.text!,
                enabled: true)
        }
        // go back to the previous view controller
        _ = self.navigationController?.popViewController(animated: true)
        
        #endif
        
    
    }
    func cancel() {
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

