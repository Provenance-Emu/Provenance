//
//  SystemsSettingsTableViewController.swift
//  Provenance
//
//  Created by Joseph Mattiello on 10/7/18.
//  Copyright © 2018 Provenance. All rights reserved.
//

import UIKit
import RealmSwift

private enum Rows {
    case gameCount(Int)
    case defaultCore(current: PVCore?, options: [PVCore])
    case bios(PVBIOS.Status)
    case settings
}

private struct SystemSectionViewModel {
    let title : String
    let rows : [Rows]
    
    init(withSystem system: PVSystem) {
        title = system.name
        var rows = [Rows]()
        rows.append(.gameCount(system.games.count))
        var defaultCore : PVCore?

        if system.cores.count > 1, let userPreferredCoreID = system.userPreferredCoreID {
            defaultCore = RomDatabase.sharedInstance.object(ofType: PVCore.self, wherePrimaryKeyEquals: userPreferredCoreID)
        } else {
            defaultCore = system.cores.first
        }

        rows.append(.defaultCore(current: defaultCore, options: Array(system.cores)))
        
        let bioses = system.bioses
        if !bioses.isEmpty {
            let statuses : [PVBIOS.Status] = Array(bioses).map {
                return Rows.bios($0.status)
            }
            rows.append(statuses)
        }
        self.rows = rows
    }
}

class SystemSettingsCell : UITableViewCell {
    static let identifier : String = String(describing: self)
}

class SystemsSettingsTableViewController: UITableViewController {

    /*
 TODO:
 - realm alert on PVBios update
     - realm alert on library update to update system games counts
 */
    fileprivate var sections : [SystemSectionViewModel]!
    var sectionsToken: NotificationToken?

    func generateViewModels() {
        let realm  = try! Realm()
        let systems = realm.objects(PVSystem.self).sorted(byKeyPath: "Name")
        sections = systems.map {
            return SystemSectionViewModel(withSystem: $0)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let realm  = try! Realm()
        sectionsToken = realm.objects(PVSystem.self).observe { (systems) in
            generateViewModels()
            self.tableView.reloadData()
        }
        
        tableView.register(SystemSettingsCell.self, forCellReuseIdentifier: SystemSettingsCell.identifier)
    }
    
    deinit {
        sectionsToken?.invalidate()
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return sections?.count ?? 0
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].rows.count
    }
    
    override func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        return sections.map { $0.title }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let rowData = sections[indexPath.section].rows[indexPath.row]
        
        let cell = tableView.dequeueReusableCell(withIdentifier: SystemSettingsCell.identifier, for: indexPath)
        
        switch rowData {
        case .bioses(let bioses):
            let bios = bioses[
            cell.textLabel?.text = stat
        case .defaultCore(let current, let options)
            break
        case .gameCount(let count)
            break
        case .settings:
            break
        }
        
        // Configure the cell...

        return cell
    }

    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
