//
//  LocalChatPeer.swift
//  SimpleChatMac
//
//  Created by Julian Asamer on 24/10/14.
//  Copyright (c) 2014 LS1 TUM. All rights reserved.
//

import Foundation
import sReto

class LocalChatPeer: NSObject {
    var displayName: String!
    @objc dynamic var chatRooms: [ChatRoom] = []
    weak var chatRoomDelegate: ChatRoomDelegate?

    var localPeer: LocalPeer!

    override init() {
    }

    /**
    * Starts the local peer. 
    * When a peer is discovered, a ChatRoom with that peer is created, when one is lost, the corresponding ChatRoom is removed.
    */
    func start(_ displayName: String) {
        self.displayName = displayName

        /**
         * Create a local peer with a WlanModule. To use the RemoteP2PModule, the RemoteP2P server needs to be deployed locally.
         */
        let wlanModule = WlanModule(type: "SimpleP2PChat", dispatchQueue: DispatchQueue.main)
        //let blueetoothModule = BluetoothModule(type: "SimpleP2PChat", dispatchQueue: dispatch_get_main_queue())
        //let remoteModule = RemoteP2PModule(baseUrl: NSURL(string: "ws://localhost:8080/")!)
        localPeer = LocalPeer(name: displayName, modules: [wlanModule], dispatchQueue: DispatchQueue.main)
        localPeer.start(onPeerDiscovered: createChatPeer, onPeerRemoved: removeChatPeer, onIncomingConnection: { peer, connection in
            print("Received incoming connection: \(connection) from peer: \(peer)")
        }, displayName: displayName)
    }

    func createChatPeer(_ remotePeer: RemotePeer) {
        print("createChatPeer")
        let chatRoom = ChatRoom(localDisplayName: displayName, remotePeer: remotePeer)
        chatRoom.delegate = self.chatRoomDelegate

        // For KVO compliance
        self.willChangeValue(forKey: "chatPeers")
        self.chatRooms.append(chatRoom)
        self.didChangeValue(forKey: "chatPeers")
    }

    func removeChatPeer(_ remotePeer: RemotePeer) {
        print("removeChatPeer")
        // For KVO compliance
        self.willChangeValue(forKey: "chatPeers")
        self.chatRooms = self.chatRooms.filter { $0.remotePeer === remotePeer }
        self.didChangeValue(forKey: "chatPeers")
    }
}
