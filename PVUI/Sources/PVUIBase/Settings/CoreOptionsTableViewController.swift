//
//  CoreOptionsTableViewController.swift
//  PVUI
//
//  Created by Joseph Mattiello on 10/7/24.
//

#if canImport(SafariServices)
import SafariServices
#endif
import PVLibrary
import PVSupport
import PVLogging

import Reachability
import RealmSwift
#if canImport(UIKit)
import UIKit
#endif
import RxSwift

import PVEmulatorCore
import PVCoreBridge
import PVThemes
import PVSettings

#if canImport(PVWebServer)
import PVWebServer
#endif

public
final class CoreOptionsTableViewController: QuickTableViewController {
    private let disposeBag = DisposeBag()

    public override func viewDidLoad() {
        super.viewDidLoad()
        splitViewController?.title = "Settings"
        generateTableViewViewModels()
        tableView.reloadData()

#if os(tvOS)
        tableView.rowHeight = UITableView.automaticDimension
        splitViewController?.view.backgroundColor = .black
        navigationController?.navigationBar.isTranslucent = false
        navigationController?.navigationBar.backgroundColor =  UIColor.black.withAlphaComponent(0.8)
#endif
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        splitViewController?.title = "Core Options"
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }

#if os(tvOS)
    private var heightDictionary: [IndexPath: CGFloat] = [:]

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        heightDictionary[indexPath] = cell.frame.size.height
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        let height = heightDictionary[indexPath]
        return height ?? UITableView.automaticDimension
    }

    public override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        cell.textLabel?.font = UIFont.systemFont(ofSize: 30, weight: UIFont.Weight.regular)
        cell.detailTextLabel?.font = UIFont.systemFont(ofSize: 20, weight: UIFont.Weight.regular)
        cell.layer.cornerRadius = 12
        return cell
    }
#endif

    func generateTableViewViewModels() {
        typealias TableRow = Row & RowStyle

        // MARK: -- Core Options
        let realm = try! Realm()
        let cores: [NavigationRow] = realm.objects(PVCore.self).sorted(byKeyPath: "projectName").compactMap { pvcore in
            guard let coreClassMaybe = NSClassFromString(pvcore.principleClass) else {
                ELOG("Class <\(pvcore.principleClass)> does not exist!")
                return .none
            }
            guard let coreClass = coreClassMaybe as? OptionalCore.Type else {
                VLOG("Class <\(pvcore.principleClass)> does not implement CoreOptional")
                return .none
            }
            return NavigationRow(text: pvcore.projectName,
                                 detailText: .none,
                                 icon: nil, customization: nil, action: { [weak self] row in
                coreClass.coreClassName = pvcore.identifier
                coreClass.systemName = (pvcore.supportedSystems.map { $0.identifier }).joined(separator: ",")
                let coreOptionsVC = CoreOptionsViewController(withCore: coreClass)
                coreOptionsVC.title = row.text
                self?.navigationController?.pushViewController(coreOptionsVC, animated: true)
            })
        }

        let coreOptionsSection = Section(title: NSLocalizedString("Core Options", comment: "Core Options"), rows: cores)

        // Set table data
        tableContents = [coreOptionsSection]
    }

    @IBAction func done(_: Any) {
        presentingViewController?.dismiss(animated: true) { () -> Void in }
    }
}
