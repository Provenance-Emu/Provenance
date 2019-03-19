//
//  ViewController.swift
//  sRetoExample
//
//  Created by Julian Asamer on 23/07/14.
//  Copyright (c) 2014 LS1 TUM. All rights reserved.
//

import UIKit
import sReto

class ViewController: UIViewController, UITableViewDelegate {
    var model = Model()
    let peerDataSource: PeerDataSource
    let connectionDataSource: ConnectionDataSource
    var localPeer: LocalPeer?
    var connections: [Connection] = []

    @IBOutlet weak var peerIdentifierLabel: UILabel!
    @IBOutlet weak var peerTableView: UITableView!
    @IBOutlet weak var connectionTableView: UITableView!
    @IBOutlet weak var inProgressView: UIProgressView!
    @IBOutlet weak var outProgressView: UIProgressView!
    @IBOutlet weak var noPeerSelectedLabel: UILabel!
    @IBOutlet weak var noConnectionSelectedLabel: UILabel!
    @IBOutlet weak var transfersView: UIView!
    @IBOutlet weak var connectionsView: UIView!
    @IBOutlet weak var previousInTransferLabel: UILabel!
    @IBOutlet weak var inTransferLabel: UILabel!
    @IBOutlet weak var previousOutTransferLabel: UILabel!
    @IBOutlet weak var outTransferLabel: UILabel!

    override init(nibName nibNameOrNil: String!, bundle nibBundleOrNil: Bundle!) {
        self.peerDataSource = PeerDataSource(model: self.model)
        self.connectionDataSource = ConnectionDataSource(model: self.model)
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    required init?(coder aDecoder: NSCoder) {
        self.peerDataSource = PeerDataSource(model: self.model)
        self.connectionDataSource = ConnectionDataSource(model: self.model)
        super.init(coder: aDecoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.peerTableView.dataSource = self.peerDataSource
        self.connectionTableView.dataSource = self.connectionDataSource
        self.peerTableView.delegate = self
        self.connectionTableView.delegate = self

        let wlanModule = WlanModule(type: "lowleveldemo", dispatchQueue: DispatchQueue.main)
//        let remoteModule = RemoteP2PModule(baseUrl: NSURL(string: "ws://localhost:8080")!)

        self.localPeer = LocalPeer(modules: [wlanModule], dispatchQueue: DispatchQueue.main)
        self.localPeer?.start(
            onPeerDiscovered: {[unowned self] in self.model.addPeer($0); self.peerTableView.reloadData() },
            onPeerRemoved: {[unowned self] in self.model.removePeer($0); self.peerTableView.reloadData() },
            onIncomingConnection: {[unowned self] peer, connection in self.configureConnection(peer, connection: connection) },
            displayName: "MyLocalPeer"
        )

        self.peerIdentifierLabel.text = "Local Peer UUID: \(localPeer!.identifier)"
    }

    func configureConnection(_ peer: RemotePeer, connection: Connection) {
        connections.append(connection)

        connection.onConnect = {
            print("onConnect: got incoming connection from peer: \(peer)")
            if let peer = self.model.examplePeer(peer) {
                peer.addConnection($0)
            }
            self.updateConnections()
        }
        connection.onTransfer = { [unowned self] peer, transfer in self.receive(peer, inTransfer: transfer) }
        connection.onClose = {
            [unowned self] in
            print("closed")
            if let peer = self.model.examplePeer($0) {
                peer.removeConnection($0)
                self.updateConnections()
            }
        }
        connection.onError = {
            [unowned self] in
            print("connection error: \($1)")
            if let peer = self.model.examplePeer($0) {
                peer.removeConnection($0)
                self.updateConnections()
            }
        }
    }

    func receive(_ connection: Connection, inTransfer: InTransfer) {
        inTransfer.onStart = {
            [unowned self] transfer in
            if let connection = self.model.exampleConnection(connection) {
                connection.inTransfer = inTransfer
                self.updateTransfers()
            }
        }
        inTransfer.onProgress = { _ in self.updateTransfers() }
        inTransfer.onCompleteData = {
            [unowned self] transfer, data in
            if let connection = self.model.exampleConnection(connection) {
                connection.previousInTransferText = "Previous In-Transfer: \(self.descriptionForTransfer(transfer))"
                connection.inTransfer = nil
                self.updateTransfers()
            }
        }
    }

    @IBAction func createConnection(_ sender: AnyObject) {
        if let peer = self.model.selectedPeer?.peer {
            let connection = peer.connect()
            self.configureConnection(peer, connection: connection)
        }
    }

    @IBAction func closeConnection() {
        if let connection = self.model.selectedPeer?.selectedConnection?.connection {
            connection.close()
            print("closing")
        }
    }

    @IBAction func send500KB(_ sender: AnyObject) {
        self.send(500*1024)
    }

    @IBAction func send1MB(_ sender: AnyObject) {
        self.send(1024*1024)
    }

    @IBAction func send5MB(_ sender: AnyObject) {
        self.send(5*1024*1024)
    }

    func send(_ bytes: Int) {
        if let exampleConnection = self.model.selectedPeer?.selectedConnection {
            let retoConnection = exampleConnection.connection
            let data = NSMutableData(length: bytes)!
            let transfer = retoConnection.send(data: data as Data)
            transfer.onStart = {
                [unowned self] _ in
                exampleConnection.outTransfer = transfer
                self.updateTransfers()
            }
            transfer.onProgress = {
                [unowned self] _ in self.updateTransfers()
            }
            transfer.onEnd = {
                [unowned self] _ in
                exampleConnection.previousOutTransferText = "Previous Out-Transfer: \(self.descriptionForTransfer(transfer))"
                exampleConnection.outTransfer = nil
                self.updateTransfers()
            }
        }
    }

    @IBAction func cancelIncomingTransfer(_ sender: AnyObject) {
        if let transfer = self.model.selectedPeer?.selectedConnection?.inTransfer {
            transfer.cancel()
        }
    }

    @IBAction func cancelOutgoingTransfer(_ sender: AnyObject) {
        if let transfer = self.model.selectedPeer?.selectedConnection?.outTransfer {
            transfer.cancel()
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if (tableView === self.peerTableView) {
            self.model.selectPeer(indexPath.row)
            self.updateConnections()
        } else {
            self.model.selectedPeer?.selectConnection(indexPath.row)
            self.updateTransfers()
        }
    }

    func updatePeers() {
        self.peerTableView.reloadData()

        self.updatePeers()
    }

    func updateConnections() {
        if self.model.selectedPeer != nil {
            self.connectionTableView.reloadData()
            self.noPeerSelectedLabel.isHidden = true
            self.connectionsView.isHidden = false
        } else {
            self.noPeerSelectedLabel.isHidden = false
            self.connectionsView.isHidden = true
        }

        self.updateTransfers()
    }

    func updateTransfers() {
        if let connection = self.model.selectedPeer?.selectedConnection {
            if let transfer = connection.inTransfer {
                self.inProgressView.progress = Float(transfer.progress) / Float(transfer.length)
                self.inTransferLabel.text = "Current Incoming Transfer: \(self.descriptionForTransfer(transfer))"
            } else {
                self.inProgressView.progress = 0
                self.inTransferLabel.text = "Current Incoming Transfer: none"
            }

            if let transfer = connection.outTransfer {
                self.outProgressView.progress = Float(transfer.progress) / Float(transfer.length)
                self.outTransferLabel.text = "Current Outgoing Transfer: \(self.descriptionForTransfer(transfer))"
            } else {
                self.outProgressView.progress = 0
                self.outTransferLabel.text = "Current Outgoing Transfer: none"
            }

            self.previousInTransferLabel.text = connection.previousInTransferText
            self.previousOutTransferLabel.text = connection.previousOutTransferText

            self.noConnectionSelectedLabel.isHidden = true
            self.transfersView.isHidden = false
        } else {
            self.noConnectionSelectedLabel.isHidden = false
            self.transfersView.isHidden = true
        }
    }

    func descriptionForTransfer(_ transfer: Transfer) -> String {
        return "\(transfer.progress) of \(transfer.length); started: \(transfer.isStarted), compl.: \(transfer.isCompleted), cancelled: \(transfer.isCancelled), all trans.: \(transfer.isAllDataTransmitted)"
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
}

class PeerDataSource: NSObject, UITableViewDataSource {
    let model: Model

    init(model: Model) {
        self.model = model
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return model.peers.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "peerCell", for: indexPath)
        cell.textLabel?.text = self.model.peers[indexPath.row].peer.identifier.UUIDString
        return cell
    }
}

class ConnectionDataSource: NSObject, UITableViewDataSource {
    let model: Model

    init(model: Model) {
        self.model = model
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let peer = self.model.selectedPeer {
            return peer.connections.count
        } else {
            return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "connectionCell", for: indexPath)

        if let peer = self.model.selectedPeer {
            cell.textLabel?.text = peer.connections[indexPath.row].description
        }

        return cell
    }
}
