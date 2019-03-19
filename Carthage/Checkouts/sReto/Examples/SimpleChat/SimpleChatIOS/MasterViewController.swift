//
//  MasterViewController.swift
//  SimpleChatIOS
//
//  Created by Julian Asamer on 27/01/15.
//  Copyright (c) 2014 LS1 TUM. All rights reserved.
//

import UIKit

class ChatPeerCell: UITableViewCell {
    fileprivate var kvoContext = 0
    fileprivate var chatPeer: ChatRoom?

    func configure(_ chatPeer: ChatRoom) {
        self.chatPeer = chatPeer
        self.textLabel?.text = chatPeer.remoteDisplayName ?? "Loading remote name..."
        chatPeer.addObserver(self, forKeyPath: "remoteDisplayName", options: .new, context: &kvoContext)
    }

    override func prepareForReuse() {
        self.chatPeer?.removeObserver(self, forKeyPath: "remoteDisplayName")
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if context == &kvoContext {
            self.textLabel?.text = chatPeer?.remoteDisplayName ?? "Loading remote name..."
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
}

class MasterViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate {
    fileprivate var kvoContext = 0
    var localPeer = LocalChatPeer()
    var detailViewController: DetailViewController?

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var displayName: UITextField!

    @IBAction func start(_ sender: AnyObject) {
        displayName.isEnabled = false
        self.localPeer = LocalChatPeer()
        self.localPeer.start(displayName.text!)
        self.localPeer.addObserver(self, forKeyPath: "chatRooms", options: .new, context: &kvoContext)
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if context == &kvoContext {
            self.tableView.reloadData()
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        if UIDevice.current.userInterfaceIdiom == .pad {
            self.preferredContentSize = CGSize(width: 320.0, height: 600.0)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        displayName.becomeFirstResponder()

        if let split = self.splitViewController {
            let controllers = split.viewControllers
            self.detailViewController = ((controllers[controllers.count-1] as! UINavigationController).topViewController as! DetailViewController)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        if let selectedIndexPath = tableView.indexPathForSelectedRow {
            self.tableView.deselectRow(at: selectedIndexPath, animated: true)
        }
    }

    // MARK: - Segues
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showDetail" {
            if let indexPath = self.tableView.indexPathForSelectedRow {
                let object = localPeer.chatRooms[indexPath.row]
                let controller = (segue.destination as! UINavigationController).topViewController as! DetailViewController
                controller.chatRoom = object
                controller.navigationItem.leftBarButtonItem = self.splitViewController?.displayModeButtonItem
                controller.navigationItem.leftItemsSupplementBackButton = true
            }
        }
    }

    // MARK: - Table View
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        print("table has \(localPeer.chatRooms.count) rows")
        return localPeer.chatRooms.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! ChatPeerCell
        let chatRoom = localPeer.chatRooms[indexPath.row]
        cell.configure(chatRoom)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.performSegue(withIdentifier: "showDetail", sender: self)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
