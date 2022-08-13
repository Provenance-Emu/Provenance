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

public enum LogViewError: Error {
    case fileCreateError
}

public final class PVLogViewController: UIViewController {
    @IBOutlet var textView: UITextView!
#if os(iOS)
    @IBOutlet var toolbar: UIToolbar!
#endif
    
    @IBOutlet var contentView: UIView!
    @IBOutlet var segmentedControl: UISegmentedControl!
    @IBOutlet var actionButton: UIBarButtonItem!
    @IBOutlet var doneButton: UIBarButtonItem!
    
    @IBAction func actionButtonPressed(_ sender: Any) {
#if os(iOS)
        try? createZipAndShare()
#endif
    }
    
    @IBAction func doneButtonClicked(_ sender: Any) {
        dismiss(animated: true)
        //        dismissModalViewController(animated: true)
    }
    
    func showLuberJackUI() {
        guard textView.isHidden else { return }
        textView.isHidden = true
        DDLog.add(PVUIForLumberJack.shared, with: .info)
        PVUIForLumberJack.shared.showLog(inView: self.contentView)
    }
    
    func hideLuberJackUI() {
        guard !textView.isHidden else { return }
        textView.isHidden = false
        DDLog.remove(PVUIForLumberJack.shared)
        PVUIForLumberJack.shared.hideLog()
    }
    
    func updateText(_ newText: String?) {
        textView.text = newText
    }
    
    deinit {
        PVLogging.shared.removeListner(listener: self)
    }
    
    public override func viewDidLoad() {
#if os(iOS)
        textView.isEditable = false
#endif
        textView.isUserInteractionEnabled = true
        textView.isScrollEnabled = true
        
        
        self.doneButton.target = self
        self.doneButton.action = #selector(doneButtonClicked)
        
        self.view.layer.cornerRadius = 9.0
        
        // Force a refesh of the tet view
        segmentedControlValueChanged(segmentedControl!)
        
        if self.navigationController != nil {
            hideDoneButton()
        }
        
        super.viewDidLoad()
    }
    
    @IBAction func logListButtonClicked(_ sender: Any) {
        /*
         // Create popover if never created
         
         UITableViewController *logsTableViewController = [[UITableViewController alloc] initWithStyle:UITableViewStylePlain];
         
         logsTableViewController.tableView.dataSource = self;
         logsTableViewController.tableView.delegate = self;
         
         #if TARGET_OS_IOS
         logsTableViewController.modalPresentationStyle = UIModalPresentationPopover;
         #endif
         logsTableViewController.popoverPresentationController.barButtonItem = self.logListButton;
         
         [self presentViewController:logsTableViewController
         animated:YES
         completion:nil];
         */
    }
    
    @IBAction func segmentedControlValueChanged(_ sender: Any) {
        //#if TARGET_OS_IOS
        //    NSMutableArray *items = [self.toolbar.items mutableCopy];
        //    if (self.segmentedControl.selectedSegmentIndex == 1 && ![items containsObject:self.logListButton]) {
        //        self.logListButton.enabled = YES;
        //        [items insertObject:self.logListButton atIndex:0];
        //        [self.toolbar setItems:items];
        //    } else if ([items containsObject:self.logListButton]){
        //        [items removeObject:self.logListButton];
        //        [self.toolbar setItems:items];
        //    }
        //#endif
        //
        //    switch(self.segmentedControl.selectedSegmentIndex){
        //
        //        case 0: {
        //            [self showLuberJackUI];
        //
        //            break;
        //        }
        //        case 1:{
        //            [self hideLumberJackUI];
        //
        //                // Fill in text
        //            [self updateText:[self logTextForIndex:0]];
        //                // Register for updates
        //            [[PVLogging sharedInstance] registerListner:self];
        //
        //            break;
        //        }
        //    }
    }
    
    func hideDoneButton() {
#if os(iOS)
        guard var items = toolbar.items else { return }
        items.removeAll(where: {$0 == doneButton!})
        toolbar.setItems(items, animated: false)
#endif
    }
    
    func position(forBar bar: UIBarPositioning) -> UIBarPosition { return .topAttached }
    
#if os(iOS)
    func createZipAndShare() throws {
        //add attachments
        guard let logFilePaths = PVLogging.shared.logFilePaths, !logFilePaths.isEmpty else {
            return
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = DateFormatter.dateFormat(fromTemplate: "yyyyMMMd-hh:mm",
                                                        options: 0,
                                                        locale: NSLocale.current)
        let fileName = "Provenance \(formatter.string(from: Date())) Logs"
        
        let zipDestination = try tmpFile(withName: fileName, extension: ".zip")
        
        // Add system logs (ASL)
        //#if !TARGET_IPHONE_SIMULATOR
        //    // Add system log Don't do it on SIM bcs it takes forever. Logs are
        //    // much larger - JOe M
        //    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0) {
        //        NSError *error;
        //        NSString *systemLogDestination = [self tmpFileWithName:[NSString stringWithFormat:@"Provenance System"]
        //                                                     extension:@".log"];
        //        NSString *systemLog = [self systemLogAsString];
        //        BOOL success =
        //        [systemLog writeToFile:systemLogDestination
        //                    atomically:YES
        //                      encoding:NSUTF8StringEncoding
        //                         error:&error];
        //        if (!success) {
        //            ELOG(@"Could not bundle system log. %@", [error localizedDescription]);
        //        } else {
        //            logFilePaths = [logFilePaths arrayByAddingObject:systemLogDestination];
        //        }
        //    }
        //#endif
        
        let zipSuccess = SSZipArchive.createZipFile(atPath: zipDestination, withFilesAtPaths: logFilePaths)
        if zipSuccess {
            let zipURL = URL.init(fileURLWithPath: zipDestination)
            
            let activityVC = UIActivityViewController.init(activityItems: [zipURL], applicationActivities: nil)
            activityVC.popoverPresentationController?.barButtonItem = self.actionButton
            present(activityVC, animated: false)
        }
    }
#endif
    func tmpFile(withName name: String, extension ext: String) throws -> String {
        // We use mkstemps() which needs 6 X's as a 'template' filename
        // it replaces those X's with random chars.
        // https://developer.apple.com/library/mac/documentation/Darwin/Reference/ManPages/man3/mkstemps.3.html
        let fileName = String(format:"%@-XXXXXX.%@", name, ext)
        let temporaryDirectory = NSTemporaryDirectory()
        var isDirectory: ObjCBool = false
        
        let exists = FileManager.default.fileExists(atPath: temporaryDirectory,
                                                    isDirectory: &isDirectory)
        if !exists {
            ILOG("Not temporay directory at path <\(temporaryDirectory)>. Creating.")
            do {
                try FileManager.default.createDirectory(atPath: temporaryDirectory, withIntermediateDirectories: true)
                ILOG("Created temporay directory")
            } catch {
                ELOG("Couldn't create temp directory: \(error.localizedDescription)")
                throw error
            }
        }
        
        let template: NSString = (NSTemporaryDirectory() as NSString).appendingPathComponent(fileName) as NSString
        try FileManager.default.removeItem(atPath: fileName)
        
        // Fill buffer with a C string representing the local file system path.
        var buffer = [Int8](repeating: 0, count: Int(PATH_MAX))
        template.getFileSystemRepresentation(&buffer, maxLength: buffer.count)
        
        // Create unique file name (and open file):
        let fd = mkstemp(&buffer)
        if fd != -1 {
            
            // Create URL from file system string:
            let url = URL(fileURLWithFileSystemRepresentation: buffer, isDirectory: false, relativeTo: nil)
            return url.path
        } else {
            ELOG("Error: " + String(cString: strerror(errno)))
            throw LogViewError.fileCreateError
        }
    }
    
    func logText(forIndex index: Int) -> String {
        guard let logs = PVLogging.shared.logFilePaths, !logs.isEmpty else {
            return "No Logs"
        }
        
        if index >= logs.count {
            return "Log index \(index) out of range \(logs.count)"
        }
        
        let logPath = logs[index]
        var logText : String
        do {
            logText = try String(contentsOfFile: logPath, encoding: .utf8)
        } catch {
            logText = error.localizedDescription
        }
        return logText
    }
    
    // MARK: - MFMailComposeViewControllerDelegate
#if os(iOS)
    public func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        if let error = error {
            let alert = UIAlertController(title: "Error sending e-mail",
                                          message: error.localizedDescription,
                                          preferredStyle: .alert)
            
            let defaultAction = UIAlertAction.init(title: "OK", style: .default)
            
            alert.addAction(defaultAction)
            self.present(alert, animated: true)
            ELOG("\(error.localizedDescription)")
        } else {
            ILOG("Support e-mail sent")
        }
        
        controller.dismiss(animated: true)
    }
#endif
    
    
}

extension PVLogViewController: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 0
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
         PVLogging.shared.flushLogs()
         updateText(logText(forIndex: indexPath.row))
         presentedViewController?.dismiss(animated: true)
     }
    
    public func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return PVLogging.shared.logFilePaths?.count ?? 0
    }
}

extension PVLogViewController: UITableViewDataSource {
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        
        //        let infos = PVLogging.shared.sortedLogFileInfos
        /*
         if (indexPath.row < infos.count) {
         DDLogFileInfo *info = infos[indexPath.row];
         
         cell.textLabel.textColor = info.isArchived ?
         [UIColor colorWithRed:.6
         green:.88
         blue:.6
         alpha:1] :
         [UIColor colorWithRed:.88
         green:.6
         blue:.6
         alpha:1];
         
         cell.textLabel.text = [NSDateFormatter localizedStringFromDate:info.creationDate
         dateStyle:NSDateFormatterShortStyle
         timeStyle:NSDateFormatterShortStyle];
         cell.detailTextLabel.text = [NSString stringWithFormat:@"Size: %.2fkb", info.fileSize/1024.];
         } else {
         cell.textLabel.text = @"Error";
         }
         
         */
        return cell
    }
}

extension PVLogViewController: PVLoggingEventProtocol {
    // MARK: - BootupHistory Protocol
    public func updateHistory(_ sender: PVLogging) {
        if segmentedControl.selectedSegmentIndex == 0 {
            updateText(sender.historyString)
        }
    }
}


#if canImport(MessageUI)
import MessageUI

extension PVLogViewController: MFMailComposeViewControllerDelegate {
    
}
#endif

