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

public final class PVUIForLumberJack: UIForLumberJack {
    public static let shared: PVUIForLumberJack = PVUIForLumberJack()
    
    var filteredTableData = [DDLogMessage]()
    
//    required init() {
//        let tableView = UITableView()
//        tableView.backgroundColor = .black
//        tableView.isOpaque          = true
//#if TARGET_OS_IOS
//        tableView.separatorStyle  = .none
//#endif
//        tableView.indicatorStyle  = .white
//        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "LogCell")
//        super.init()
//        self.tableView = tableView
//        tableView.delegate        = self
//        tableView.dataSource      = self
//    }
    
//    required init?(coder: NSCoder) {
//        fatalError("init(coder:) has not been implemented")
//    }
    
    // MARK: Content Filtering
    // TODO: Filtering  - just need to swap out _filteredTableData for _messages in the tableview delegeate
    // probably best to fork PVUIForLumberJack.
    func filterContent(forSearchText searchText:String, scope: String) {
        // Update the filtered array based on the search text and scope.
        // Remove all objects from the filtered search array
        filteredTableData.removeAll(keepingCapacity: true)
        // Filter the array using NSPredicate
        // Filte on log contents. Could use error type as well in the future
//        let predicate = NSPredicate.init(format: "SELF.logMsg contains[c] %@", searchText)
        filteredTableData = self.messages.filter({
            $0.message.lowercased().contains(searchText.lowercased())
        })
    }
    
    public var supportedInterfaceOrientations: UIInterfaceOrientationMask { return .all }
    
    func logMessage(_ logMessage: DDLogMessage) {
        self.messages.append(logMessage)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let isVisible = self.tableView.superview != nil
            if isVisible {
                self.addRow()
            }
        }
    }
    
    var zipLogFiles: String {
        let logging = PVLogging.shared
        
        logging.flushLogs()
        
        guard let files = logging.logFilePaths, !files.isEmpty else {
            ELOG("No log files")
            return ""
        }
        let tempDir: NSString = NSTemporaryDirectory() as NSString
        
        do {
            try FileManager.default.createDirectory(atPath: tempDir as String, withIntermediateDirectories: true)
            let zipPath = tempDir.appendingPathComponent("logs.zip")
            
            SSZipArchive.createZipFile(atPath: zipPath, withFilesAtPaths: files)
            
            return zipPath
        } catch {
            ELOG(error.localizedDescription)
            return ""
        }
    }
    
    private func addRow() {
        // Store the count. Message is type atomic so
        // this should be thread safe once stored
        if messages.isEmpty {
            
        } else {
            let count = messages.count
            let numberOfRows = self.tableView.numberOfRows(inSection: 0)
            var indexes = [IndexPath]()
            
            if numberOfRows == count {
                // Cells were already added in previous
                // batch
                return
            }
            
            var scroll = false
            if (self.tableView.contentOffset.y + self.tableView.bounds.size.height >= (self.tableView.contentSize.height - 20)) {
                scroll = true
            }
            
            // Calcuate index path(s) that need addign
            
            var indexPath: IndexPath?
            for i in (numberOfRows-1) ..< count {
                let ip = IndexPath(row: i, section: 0)
                indexPath = ip
                indexes.append(ip)
            }
            
            self.tableView.insertRows(at: indexes, with: .bottom)
            
            if let indexPath = indexPath, scroll {
                self.tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
            }
        }
    }
    
    override public func showLog(inView view: UIView) {
        self.tableView.reloadData()
    }
    
    // MARK: Content Filtering
    // TODO: Filtering  - just need to swap out _filteredTableData for _messages in the tableview delegeate
    // probably best to fork PVUIForLumberJack.
    //    func filterContent(forSearchText searchText: String, scope: String) {
    //        // Update the filtered array based on the search text and scope.
    //        // Remove all objects from the filtered search array
    //        _filteredTableData.removeAllObjects()
    //        // Filter the array using NSPredicate
    //        // Filte on log contents. Could use error type as well in the future
    //        let predicate = NSPredicate.init(format: "SELF.logMsg contains[c] %@", searchText)
    //
    //        _filteredTableData = (messages as NSArray).filtered(using: predicate)
    //    }
    
    public override func hideLog() {
        self.tableView.removeFromSuperview()
    }
}

extension PVUIForLumberJack { //: UITableViewDataSource {
    public override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
       return nil
    }

    public override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    public override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }
}

extension PVUIForLumberJack { //: UITableViewDelegate {
    public override func tableView(_ tableView: UITableView, estimatedHeightForHeaderInSection section: Int) -> CGFloat {
        return 0
    }
    
    public func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 0
    }
}
