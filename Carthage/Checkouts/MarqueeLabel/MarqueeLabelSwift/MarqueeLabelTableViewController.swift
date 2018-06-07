//
//  MarqueeLabelTableViewController.swift
//  MarqueeLabelDemo
//
//  Created by Charles Powell on 3/26/16.
//
//

import UIKit

class MarqueeLabelTableViewController: UITableViewController {
    let strings = ["When shall we three meet again in thunder, lightning, or in rain? When the hurlyburly's done, When the battle 's lost and won.",
                   "I have no spur to prick the sides of my intent, but only vaulting ambition, which o'erleaps itself, and falls on the other.",
                   "Double, double toil and trouble; Fire burn, and cauldron bubble.",
                   "By the pricking of my thumbs, Something wicked this way comes.",
                   "My favorite things in life don't cost any money. It's really clear that the most precious resource we all have is time.",
                   "Be a yardstick of quality. Some people aren't used to an environment where excellence is expected."]
    
    override func viewDidLoad() {
        if let tabBar = tabBarController?.tabBar {
            var tabBarInsets = UIEdgeInsetsMake(0.0, 0.0, tabBar.bounds.height, 0.0)
            tableView.contentInset = tabBarInsets
            tabBarInsets.top = 84
            tableView.scrollIndicatorInsets = tabBarInsets
        }
        
        let headerNib = UINib(nibName: "MLHeader", bundle:nil)
        tableView.register(headerNib, forHeaderFooterViewReuseIdentifier: "MLHeader")
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 30
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return tableView.dequeueReusableHeaderFooterView(withIdentifier: "MLHeader")
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 84.0
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MLCell", for: indexPath) as! MLCell
        
        cell.label.text = strings[Int(arc4random_uniform(UInt32(strings.count)))]
        cell.label.type = .continuous
        cell.label.speed = .duration(15)
        cell.label.animationCurve = .easeInOut
        cell.label.fadeLength = 10.0
        cell.label.leadingBuffer = 14.0
        
        // Labelize normally, to improve scroll performance
        cell.label.labelize = true
        
        // Set background, to improve scroll performance
        cell.backgroundColor = UIColor.white
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let cell = tableView.cellForRow(at: indexPath) as! MLCell
        
        // De-labelize on selection
        cell.label.labelize = false
    }
    
    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // Re-labelize all scrolling labels on tableview scroll
        for cell in tableView.visibleCells as! [MLCell] {
            cell.label.labelize = true
        }
        
        // Animate border
        let header = tableView.headerView(forSection: 0) as! MLHeader
        UIView.animate(withDuration: 0.2) { 
            header.border.alpha = (scrollView.contentOffset.y > 1.0 ? 1.0 : 0.0)
        }
    }
}

class MLCell: UITableViewCell {
    @IBOutlet weak var label: MarqueeLabel!
}

class MLHeader: UITableViewHeaderFooterView {
    @IBOutlet weak var border: UIView!
}
