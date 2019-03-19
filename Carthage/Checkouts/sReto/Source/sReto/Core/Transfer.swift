//
//  Transfer.swift
//  sReto
//
//  Created by Julian Asamer on 14/07/14.
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
* A Transfer object represents a data transfer between two or more peers. 
* It has two subclasses, InTransfer and OutTransfer, which represent an incoming transfer (i.e. a data transfer that is being received) and an outgoing transfer (i.e. a data transfer that is being sent to some other peer).
* OutTransfers are created by calling one of the send methods on the Connection class.
* InTransfers are created by the Connection class when the connected peer starts a data transfer. At this point, the connection's onTransfer event is invoked. Thus, InTransfers can be obtained by using the onTransfer event exposed by the Connection class.
*/
open class Transfer {
    // MARK: Events

    // Called when the transfer starts. If this property is set when the transfer is already started, the closure is called immediately.
    open var onStart: ((Transfer) -> Void)? = nil {
        didSet { if isStarted { onStart?(self) } }
    }
    // Called whenever the transfer makes progress.
    open var onProgress: ((Transfer) -> Void)?
    // Called when the transfer completes successfully. To receive the data from an incoming transfer, use onCompleteData or onPartialData of InTransfer.
    open var onComplete: ((Transfer) -> Void)? = nil {
        didSet { if isCompleted { onComplete?(self) } }
    }
    // Called when the transfer is cancelled.
    open var onCancel: ((Transfer) -> Void)? = nil {
        didSet { if isCancelled { onEnd?(self) } }
    }
    // Called when the transfer ends, either by cancellation or completion.
    open var onEnd: ((Transfer) -> Void)? = nil {
        didSet { if isCompleted || isCancelled { onEnd?(self) } }
    }

    // MARK: Properties
    /** The transfer's length in bytes*/
    open let length: Int
    /** Whether the transfer was been started */
    open internal(set) var isStarted: Bool = false
    /** Whether the transfer was completed successfully */
    open internal(set) var isCompleted: Bool = false
    /** Whether the transfer was cancelled */
    open internal(set) var isCancelled: Bool = false
    /** Indicates if the transfer is currently interrupted. This occurs, for example, when a connection closes unexpectedly. The transfer is resumed automatically on reconnect. */
    open internal(set) var isInterrupted: Bool = false
    /** The transfer's current progress in bytes */
    open internal(set) var progress: Int = 0
    /** Whether all data was sent. */
    open var isAllDataTransmitted: Bool { get { return self.progress == self.length } }

    /** 
    * Cancels the transfer. If the transfer is an incoming transfer, calling this method requests the cancellation from the sender.
    * This may take a little time. It is therefore possible that additional data is received, or even that the transfer completes before the cancel request reaches the sender. 
    * When the transfer is cancelled successfully, the onCancel event is called. You should use this event to determine whether the transfer is actually cancelled, and not assume that it's cancelled after calling the cancel method.
    */
    open func cancel() {}

    // MARK: Internal

    /** The transfer's identifier */
    internal let identifier: UUID
    /** The transfer's manager. */
    internal weak var manager: TransferManager?

    /** 
    * Constructs a Transfer.
    * @param manager The TransferManager responsible for this transfer.
    * @param length The total length of the transfer in bytes.
    * @param identifier The transfer's identifier.
    */
    internal init(manager: TransferManager, length: Int, identifier: UUID) {
        self.manager = manager
        self.length = length
        self.identifier = identifier
    }

    /** Updates the transfer's progress. */
    internal func updateProgress(_ numberOfBytes: Int) {
        assert(self.length >= self.progress+numberOfBytes, "Can not update the transfer's progress beyond its length.")

        self.progress += numberOfBytes
    }

    /** Call to change the transfer's state to started and dispatch the associated events. */
    internal func confirmStart() {
        self.isStarted = true
        self.onStart?(self)
    }
    /** Call to confirm updated progress and dispatch the associated events. */
    internal func confirmProgress() {
        self.onProgress?(self)
    }
    /** Call to change thet transfer's state to cancelled and dispatch the associated events. */
    internal func confirmCancel() {
        self.isCancelled = true
        self.onCancel?(self)
        self.confirmEnd()
    }
    /** Call to change thet transfer's state to completed and dispatch the associated events. */
    internal func confirmCompletion() {
        self.isCompleted = true
        self.onComplete?(self)
        self.confirmEnd()
    }
    /** Call to change thet transfer's state to ended, dispatch the associated events, and clean up events. */
    internal func confirmEnd() {
        self.onEnd?(self)

        self.onStart = nil
        self.onProgress = nil
        self.onComplete = nil
        self.onCancel = nil
        self.onEnd = nil
    }
}
