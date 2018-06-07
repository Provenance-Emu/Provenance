//
//  ViewController.swift
//  Demo-tvOS
//
//  Created by toshi0383 on 1/9/16.
//  Copyright © 2016 Charles Powell. All rights reserved.
//

import UIKit

let labels = [
    "Lorem ipsum dolor sit amet.",
    "Lorem ipsum dolor sit amet, consectetur.",
    "Lorem ipsum dolor sit amet, consectetur adipiscing.",
    "Lorem ipsum dolor sit amet, consectetur adipiscing elit.",
    "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed id.",
    "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed id ultricies justo.",
    "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed id ultricies justo. Praesent eleifend."]

let defaultScrollDuration: CGFloat = 20.0

class ViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet var marqueeTableView: UITableView!
    @IBOutlet var labelTableView: UITableView!

    override func viewDidLoad() {
        super.viewDidLoad()
        // MarqueeLabel Tableview
        marqueeTableView.dataSource = self
        marqueeTableView.delegate = self
        
        // Basic UILabel Tableview
        labelTableView.dataSource = self
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return labels.count * 10
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.cellText = labels[(indexPath as NSIndexPath).row % labels.count]
        return cell
    }
    
    func tableView(_ tableView: UITableView, didUpdateFocusIn context: UITableViewFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        if tableView == marqueeTableView {
            if let previouslyFocusedIndexPath = context.previouslyFocusedIndexPath {
                let previous = tableView.cellForRow(at: previouslyFocusedIndexPath) as? MarqueeCell
                previous?.marquee.labelize = true
            }
            if let nextFocusedIndexPath = context.nextFocusedIndexPath {
                let next = tableView.cellForRow(at: nextFocusedIndexPath) as? MarqueeCell
                next?.marquee.labelize = false
            }
        }
    }
}

protocol TextCell {
    var cellText: String? { get set }
}

class MarqueeCell: UITableViewCell {
    @IBOutlet var marquee: MarqueeLabel!
    
    override func awakeFromNib() {
        // Perform initial setup
        marquee.labelize = true
        marquee.fadeLength = 7.0
        marquee.speed = .duration(defaultScrollDuration)
        marquee.lineBreakMode = .byTruncatingTail
    }
    
    override var cellText: String? {
        get {
            return marquee.text
        }
        set {
            marquee.text = newValue
        }
    }
}

extension UITableViewCell: TextCell {
    @objc var cellText: String? {
        get {
            return textLabel?.text
        }
        set {
            textLabel?.text = newValue
        }
    }
}
