//
//  PVLogViewController.swift
//  Provenance
//
//  Created by Joseph Mattiello on 8/10/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import UIKit

import QuartzCore
import ZipArchive
import PVSupport
import CocoaLumberjackSwift

public class UIForLumberJack: NSObject, DDLogger {
    public var logFormatter: DDLogFormatter?
        
    public var tableView: UITableView
    public var messages = [DDLogMessage]()
    public var messagesExpanded = Set<Int>.init(minimumCapacity: 20)
    public let dateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss:SSS"
        return df
    }()
    
    public required override init() {
        let tableView = UITableView()
        tableView.backgroundColor = .black
        tableView.isOpaque          = true
#if TARGET_OS_IOS
        tableView.separatorStyle  = .none
#endif
        tableView.indicatorStyle  = .white
        self.tableView = tableView
        super.init()

        tableView.delegate        = self
        tableView.dataSource      = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "LogCell")
    }
    
    public func log(message: DDLogMessage) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.messages.append(message)
            var scroll = false
            let tableView = self.tableView
            if tableView.contentOffset.y + tableView.bounds.size.height >= tableView.contentSize.height {
                scroll = true
            }
            
            
            let indexPath = IndexPath(row: self.messages.count - 1, section: 0)
            tableView.insertRows(at: [indexPath], with: .bottom)
            
            if scroll {
                self.tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
            }
        }
    }
    
    public func showLog(inView view: UIView) {
        view.addSubview(tableView)
        let tv = tableView
        tv.translatesAutoresizingMaskIntoConstraints = false
        let c1 = NSLayoutConstraint.constraints(withVisualFormat: "H:|[tv]|", metrics: nil, views: ["tv": tv])
        let c2 = NSLayoutConstraint.constraints(withVisualFormat: "V:|[tv]|", metrics: nil, views: ["tv": tv])
        
        view.addConstraints(c1)
        view.addConstraints(c2)
    }
    
    @objc public func hideLog() {
        tableView.removeFromSuperview()
    }
}

extension UIForLumberJack: UITableViewDataSource {
    public func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "LogCell", for: indexPath)
        configureCell(cell: cell, forRowAtIndexPath: indexPath)
        return cell
    }
    
    func configureCell(cell: UITableViewCell, forRowAtIndexPath indexPath: IndexPath) {
        guard let textLabel = cell.textLabel else { return }
        let message: DDLogMessage = messages[indexPath.row]
        switch message.flag {
        case .error: textLabel.textColor = .red
        case .warning: textLabel.textColor = .orange
        case .debug: textLabel.textColor = .green
        case .verbose: textLabel.textColor = .blue
        case .info:
            textLabel.textColor = .white
        default:
            textLabel.textColor = .white
        }
        
        textLabel.text = textOfMessage(forIndexPath: indexPath)
        textLabel.font = fontOfMessage
        textLabel.numberOfLines = 0
        cell.backgroundColor = .clear
    }
    
    func textOfMessage(forIndexPath indexPath : IndexPath) -> String {
        let message: DDLogMessage = messages[indexPath.row]
        if messagesExpanded.contains(indexPath.row) {
            return String(format: "[%@] %@:%lu [%@]", dateFormatter.string(from: message.timestamp), message.fileName, message.line, message.function!);
        } else {
            return String(format: "[%@] %@", dateFormatter.string(from: message.timestamp), message.message)
        }
    }
    
    var fontOfMessage: UIFont { return UIFont.boldSystemFont(ofSize: 9) }
}

extension UIForLumberJack: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let closeButton = UIButton.init(type: .custom)
        
        closeButton.setTitle("Hide Log", for: .normal)
        closeButton.backgroundColor = UIColor.init(red: 59/255.0, green: 209/255.0, blue: 65/255.0, alpha: 1)
        closeButton.addTarget(self, action: #selector(hideLog), for: .touchUpInside)
        return closeButton
    }
    
    public func tableView(_ tableView: UITableView, estimatedHeightForHeaderInSection section: Int) -> CGFloat {
        return 44
    }
    
    public func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        var estimatedNumberOflines = 1
        let row = indexPath.row
        if row < self.messages.count {
            let line: DDLogMessage = self.messages[row]
            estimatedNumberOflines = Int(Double(line.message.count / 150).rounded(.up))
        }
        return CGFloat(20 * estimatedNumberOflines)
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let index = indexPath.row
        if messagesExpanded.contains(index) {
            messagesExpanded.remove(index)
        } else {
            messagesExpanded.insert(index)
        }
        tableView.deselectRow(at: indexPath, animated: true)
        tableView.reloadRows(at: [indexPath], with: .fade)
    }
}
