//
//  ChatRoom.swift
//  SimpleChatMac
//
//  Created by Julian Asamer on 24/10/14.
//  Copyright (c) 2014 LS1 TUM. All rights reserved.
//

import Foundation
import sReto

/**
 The ChatRoomDelegate protocol is used mostly to ask the delegate for a file path which to write a received file to, and to inform it about a completed transfer.
*/
protocol ChatRoomDelegate: class {
    func chatRoom(_: ChatRoom, pathForSavingFileWithName: String) throws -> String?
    func chatRoom(_: ChatRoom, completedReceivingFileAtPath: String) throws
}

/*
Each ChatRoom represents a chat conversation with the peer it represents.

For simplicity, when a chat room is created, a connection is created to the remote peer, which is used to send chat messages.
This means that both participating peers create a connection, i.e. there are two connections between the peers, even though one would be enough.

Files can be exchanged in using the ChatRoom class. To transmit a file, a new connection is established. First, the file name is transmitted, then the actual file.
After transmission, the connection is closed.

Therefore, the first incoming connection from a remote peer is used to receive chat messages; any further connections are used to receive files.
*/
class ChatRoom: NSObject {
    weak var delegate: ChatRoomDelegate?

    /** The display name of the local peer in the chat */
    @objc dynamic var localDisplayName: String
    /** The display name of the remote peer in the chat */
    @objc dynamic var remoteDisplayName: String?
    /** The initial display name of the remote peer in the chat */
    @objc dynamic var initialRemoteDisplayName: String?
    /** The full text in the chat room; contains all messages. */
    @objc dynamic var chatText = ""
    /** The progress of a file if it one is being transmitted. */
    @objc dynamic var fileProgress: Int = 0
    /** Whether a file is currently being transmitted. */
    var isFileTransferActive: Bool {
        return self.fileProgress != 0
    }

    /** The remotePeer object representing the other peer in the chat room (besides the local peer) */
    let remotePeer: RemotePeer
    /** The connection used to send chat messages. */
    let outgoingConnection: Connection
    /** Whether the first connection, i.e. the connection used to receive messages, was already accepted. */
    var didAcceptMessageConnection = false
    /** The path to which the current file transfer, if any, is written. */
    var filePath: String?

    init(localDisplayName: String, remotePeer: RemotePeer) {
        self.localDisplayName = localDisplayName
        self.remotePeer = remotePeer
        //TODO: use this information properly
        self.initialRemoteDisplayName = remotePeer.name
        // Create a connection to the remote peer
        self.outgoingConnection = remotePeer.connect()

        super.init()

        // When an incoming connection is available, call acceptConnection.
        remotePeer.onConnection = { [unowned self] in
            self.acceptConnection($0, connection: $1)
        }

        // The first message sent through the outgoing connection contains the display name that should be used, so it is sent here.
        let data = self.localDisplayName.data(using: String.Encoding.utf8)!
        _ = self.outgoingConnection.send(data: data)
    }

    func acceptConnection(_ peer: RemotePeer, connection: Connection) {
        if !didAcceptMessageConnection {
            // If this is the first connection, we use it to receive message data. Therefore we call handleChatMessageData when data was received.
            connection.onData = { [unowned self] in self.handleChatMessageData($0) }
            self.didAcceptMessageConnection = true
        } else {
            // Any additional connections are used to receive a file transfer.
            connection.onTransfer = self.receiveFile
        }
    }

    func sendMessage(_ message: String) {
        // Append the message to the local chatText
        appendChatMessage(message, displayName: localDisplayName)

        // Serialize & send the chat message
        let data = message.data(using: String.Encoding.utf8)!
        _ = self.outgoingConnection.send(data: data)
    }

    func handleChatMessageData(_ data: Data) {
        if let message = String(data: data, encoding: String.Encoding.utf8) {
            // The first message is the remote display name. If we don't know it yet, that means that we received the display name. Otherwise, append the chat message.
            if remoteDisplayName == nil {
                remoteDisplayName = message
            } else {
                appendChatMessage(message, displayName: remoteDisplayName!)
            }
        }
    }

    func appendChatMessage(_ message: String, displayName: String) {
        chatText = "\(chatText)\(displayName): \(message)\n"
    }

    func sendFile(_ path: String) {
        // Get some properties of the file
        let fileHandle = FileHandle(forReadingAtPath: path)!

        // Establish a new connection to transmit the file.
        let connection = self.remotePeer.connect()

        // Send the file name
        let fileName: String = URL(fileURLWithPath: path).lastPathComponent
        _ = connection.send(data: fileName.data(using: String.Encoding.utf8)!)

        // Send the file itself. Data will be read as the file is being sent.
        let transfer = connection.send(data: self.readData(fileHandle))

        // When progress is made, we update the file progress property.
        transfer.onProgress = self.updateProgress
        // When the transfer is done, we reset the progress and close the file handle.
        transfer.onEnd = { t in
            self.endTransfer(fileHandle)
            self.fileProgress = 0
        }
    }

    func receiveFile(_ connection: Connection, transfer: InTransfer) {
        // receiveFile will be called twice; once for the transfer that contains the fileName only, and once for the actual file.
        // If we already have a filePath, we can receive the file.
        if let filePath = filePath {
            FileManager.default.createFile(atPath: filePath, contents: nil, attributes: nil)
            let fileHandle = FileHandle(forWritingAtPath: filePath)!

            // Whenever data is received, we write data to the file handle.
            transfer.onPartialData = { _, data in self.writeData(fileHandle, data) }
            // When progress is made, update the progress property
            transfer.onProgress = self.updateProgress
            // When everything is received, close the connection, close the file handle, and inform the delegate that a file was received.
            transfer.onEnd = {
                _ in
                connection.close()
                self.endTransfer(fileHandle)
                do {
                    try self.delegate?.chatRoom(self, completedReceivingFileAtPath: filePath)
                } catch {
                    print(error)
                }
                self.fileProgress = 0
            }
            // Reset the file path.
            self.filePath = nil
        } else {
            // Otherwise, we need to receive the fileName, and create a path by requesting a save directory from the delegate.
            transfer.onCompleteData = {
                transfer, data in
                let fileName = String(data: data, encoding: String.Encoding.utf8)
                do {
                    if let fileName = fileName, let saveFileName = try self.delegate?.chatRoom(self, pathForSavingFileWithName: fileName as String) {
                        self.filePath = saveFileName
                    } else {
                        // If the delegate doesn't return a save path (e.g. because the user cancelled the save file dialogue, we close the connection early.
                        connection.close()
                    }
                } catch {
                    print(error)
                }
            }
        }
    }

    func readData(_ fileHandle: FileHandle) -> Data {
        return fileHandle.readDataToEndOfFile()
    }

    func writeData(_ fileHandle: FileHandle, _ data: Data) {
        fileHandle.write(data)
    }

    func updateProgress(_ transfer: Transfer) {
        self.fileProgress = (transfer.progress * 100)/transfer.length
    }

    func endTransfer(_ fileHandle: FileHandle) {
        fileHandle.closeFile()
    }
}
