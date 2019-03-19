//
//  Model.swift
//  sRetoExample
//
//  Created by Julian Asamer on 24/07/14.
//  Copyright (c) 2014 LS1 TUM. All rights reserved.
//

import Foundation
import sReto

class Model {
    var peers: [ExamplePeer] = []
    var selectedPeer: ExamplePeer?

    init() {
    }

    func addPeer(_ peer: RemotePeer) {
        self.peers.append(ExamplePeer(peer: peer))
    }

    func removePeer(_ peer: RemotePeer) {
        print("removing: \(peer), existing: \(peer)")
        self.peers = self.peers.filter({ existingPeer in existingPeer.peer !== peer})
        if self.selectedPeer === peer {
            self.selectedPeer = nil
        }
    }
    func selectPeer(_ index: Int) {
        self.selectedPeer = peers[index]
    }

    func examplePeer(_ peer: RemotePeer) -> ExamplePeer? {
        print("peers here: \(self.peers)")
        for examplePeer in self.peers {
            if examplePeer.peer === peer {
                return examplePeer
            }
        }
        return nil
    }
    func examplePeer(_ connection: Connection) -> ExamplePeer? {
        for examplePeer in self.peers {
            for econnection in examplePeer.connections {
                if econnection.connection === connection {
                    return examplePeer
                }
            }
        }
        return nil
    }
    func exampleConnection(_ connection: Connection) -> ExampleConnection? {
        for examplePeer in self.peers {
            for econnection in examplePeer.connections {
                if econnection.connection === connection {
                    return econnection
                }
            }
        }
        return nil
    }
}

class ExamplePeer {
    let peer: RemotePeer
    var connections: [ExampleConnection] = []
    var selectedConnection: ExampleConnection?

    init(peer: RemotePeer) {
        self.peer = peer
    }

    func selectConnection(_ index: Int) {
        self.selectedConnection = self.connections[index]
    }
    func addConnection(_ connection: Connection) {
        self.connections.append(ExampleConnection(connection: connection))
    }
    func removeConnection(_ connection: Connection) {
        self.connections = self.connections.filter { existingConnection in existingConnection.connection !== connection }
        if connection === self.selectedConnection {
            self.selectedConnection = nil
        }
    }
}

class ExampleConnection {
    let description: String
    let connection: Connection
    var transfers: [Transfer]?
    var inTransfer: InTransfer?
    var outTransfer: Transfer?
    var previousInTransferText = ""
    var previousOutTransferText = ""

    init(connection: Connection) {
        self.connection = connection
        self.description = NSDate().description
    }
}
