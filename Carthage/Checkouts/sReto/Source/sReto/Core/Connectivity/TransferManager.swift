//
//  TransferManager.swift
//  sReto
//
//  Created by Julian Asamer on 26/07/14.
//  Copyright (c) 2014 - 2016 Chair for Applied Software Engineering
//
//  Licensed under the MIT License
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
//  The software is provided "as is", without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness
//  for a particular purpose and noninfringement. in no event shall the authors or copyright holders be liable for any claim, damages or other liability, 
//  whether in an action of contract, tort or otherwise, arising from, out of or in connection with the software or the use or other dealings in the software.
//

import Foundation

/**
* The TransferManagerDelegate protocol informs the delegate when an incoming transfer starts.
*/
protocol TransferManagerDelegate: class {
    /** Called when an incoming transfer starts. */
    func notifyTransferStarted(_ transfer: InTransfer)
}

/**
* The TransferManager class is responsible to perform data transfers. It supports resuming transfers after a connection failed during a transfer, 
* and the cancellation of transfers.
*/
class TransferManager: PacketHandler {
    /** The TransferManager's delegate.*/
    weak var delegate: TransferManagerDelegate?

    /** The packetConnection used to send and receive packets. */
    let packetConnection: PacketConnection
    /** Whether all transfers are currently interrupted. This is the case when a packet connection's underlying connection fails. */
    var isInterrupted = false
    /** The transfer that is currently being received. */
    var currentInTransfer: InTransfer?
    /** The transfer that is currently being sent. */
    var currentOutTransfer: OutTransfer?
    /** A queue of transfers that will be sent next. */
    var outTransferQueue: Queue<OutTransfer> = Queue()
    /** The size of data packets in bytes. */
    var packetSize: Int {
        return self.packetConnection.underlyingConnection?.recommendedPacketSize ?? 1024
    }

    /** 
    * Constructs a new TransferManager.
    * 
    * @param packetConnection The PacketConnection used to send and receive data transfers.
    */
    init(packetConnection: PacketConnection) {
        self.packetConnection = packetConnection
        self.packetConnection.addDelegate(self)
        if packetConnection.isConnected {
            packetConnection.write()
        }
    }

    /** 
    * Starts a transfer.
    *
    * @param dataLength The length of the transfer in bytes.
    * @param dataProvider A function that returns data for a given range.
    * @return An OutTransfer object.
    */
    func startTransfer(_ dataLength: Int, dataProvider: @escaping (_ range: Range<Data.Index>) -> Data) -> OutTransfer {
        let outTransfer = OutTransfer(manager: self, dataLength: dataLength, dataProvider: dataProvider, identifier: randomUUID())
        self.outTransferQueue.enqueue(outTransfer)
        self.packetConnection.write()

        return outTransfer
    }

    /** Cancels an incoming transfer. */
    func cancel(_ transfer: InTransfer) {
        if (transfer === self.currentInTransfer) { self.packetConnection.write(CancelledTransferPacket(transferIdentifier: transfer.identifier)) } else { log(.high, error: "Could not cancel unknown in transfer.") }

        self.packetConnection.write()
    }

    /** Cancels an outgoing transfer. */
    func cancel(_ transfer: OutTransfer) {
        let isCurrentTransfer: (OutTransfer) -> Bool = { queuedTransfer in transfer === queuedTransfer }

        if self.outTransferQueue.anyMatch(isCurrentTransfer) {
            self.outTransferQueue.filter(isCurrentTransfer)
            transfer.confirmCancel()
        } else if self.currentOutTransfer === transfer {
            self.packetConnection.write(CancelledTransferPacket(transferIdentifier: transfer.identifier))
            transfer.confirmCancel()
            self.currentOutTransfer = nil
        }

        self.packetConnection.write()
    }

    // MARK: PacketHandler protocol

    func underlyingConnectionDidClose(_ error: AnyObject?) {
    }

    func willSwapUnderlyingConnection() {
        if self.isInterrupted { return }

        self.isInterrupted = true
        if let transfer = self.currentInTransfer {
            transfer.isInterrupted = true
        }
        if let transfer = self.currentOutTransfer {
            transfer.isInterrupted = true
        }
    }

    func underlyingConnectionDidConnect() {
        if self.isInterrupted {
            if let transfer = self.currentInTransfer {
                let info = ProgressInformation(transferIdentifier: transfer.identifier, progress: Int32(transfer.progress))
                self.packetConnection.write(ProgressInformationPacket(information: [info]))
            } else {
                self.packetConnection.write(ProgressInformationPacket(information: []))
            }
        }
        self.packetConnection.write()
    }

    func didWriteAllPackets() {
        if self.isInterrupted { return }

        if let currentTransfer = self.currentOutTransfer {
            self.packetConnection.write(currentTransfer.nextPacket(self.packetSize))
            currentTransfer.confirmProgress()

            if currentTransfer.isAllDataTransmitted {
                self.currentOutTransfer = nil
                currentTransfer.confirmCompletion()
            }
        } else if let nextTransfer = self.outTransferQueue.dequeue() {
            self.currentOutTransfer = nextTransfer
            nextTransfer.confirmStart()
            self.packetConnection.write(StartedTransferPacket(transferIdentifier: nextTransfer.identifier, transferLength: Int32(nextTransfer.length)))
        }
    }

    let handledPacketTypes = [
        PacketType.progressInformation,
        PacketType.transferStarted,
        PacketType.cancelledTransfer,
        PacketType.dataPacket
    ]

    func handlePacket(_ data: DataReader, type: PacketType) {
        switch type {
        case .progressInformation:
            if let packet = ProgressInformationPacket.deserialize(data) { self.handleProgressInformation(packet) }
        case .transferStarted:
            if let packet = StartedTransferPacket.deserialize(data) { self.handleStartedTransfer(packet) }
        case .cancelledTransfer:
            if let packet = CancelledTransferPacket.deserialize(data) { self.handleCancelledTransfer(packet) }
        case .dataPacket:
            if let packet = DataPacket.deserialize(data) { self.handleData(packet) }
        default: log(.high, error: "Packet of type \(type) cannot be handled by TransferManager.")
        }
    }

    // MARK: Private
    /** Called when progress information about a transfer is received. The affected transfer's progress is set according to the information received. */
    fileprivate func handleProgressInformation(_ packet: ProgressInformationPacket) {
        for progressInfo in packet.information {
            if let outTransfer = self.currentOutTransfer {
                if outTransfer.identifier == progressInfo.transferIdentifier {
                    outTransfer.progress = Int(progressInfo.progress)
                    outTransfer.isInterrupted = false
                } else {
                    log(.medium, error: "received progress information identifier did not match current transfer identifier")
                }
            } else {
                log(.medium, error: "received progress information, but there is no current out transfer")
            }
        }

        if let transfer = self.currentOutTransfer {
            if transfer.isInterrupted {
                transfer.isInterrupted = false
                transfer.progress = 0
            }
        }

        self.isInterrupted = false
        self.packetConnection.write()
    }

    /** Called when a transfer is started. */
    fileprivate func handleStartedTransfer(_ packet: StartedTransferPacket) {
        assert(self.currentInTransfer == nil, "Received started transfer packet, but there is still an active in tansfer")
        self.currentInTransfer = InTransfer(manager: self, length: Int(packet.transferLength), identifier: packet.transferIdentifier)
        self.delegate?.notifyTransferStarted(self.currentInTransfer!)
        self.currentInTransfer?.confirmStart()
    }

    /** Handles a cancelled transfer packet. */
    fileprivate func handleCancelledTransfer(_ packet: CancelledTransferPacket) {
        if let transfer = self.currentOutTransfer {
            if transfer.identifier == packet.transferIdentifier {
                self.cancel(transfer)
            }
        }

        if let transfer = self.currentInTransfer {
            if transfer.identifier == packet.transferIdentifier {
                transfer.confirmCancel()
                self.currentInTransfer = nil
            }
        }
    }

    /** Handles a data packet. */
    fileprivate func handleData(_ packet: DataPacket) {
        assert(self.currentInTransfer != nil, "Received data, but there is no incoming transfer")

        if let transfer = self.currentInTransfer {
            transfer.updateWithReceivedData(packet.data)
            transfer.confirmProgress()
            if transfer.isAllDataTransmitted {
                self.currentInTransfer = nil
                transfer.confirmCompletion()
            }
        }
    }
}
