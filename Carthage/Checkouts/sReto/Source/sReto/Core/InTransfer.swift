//
//  InTransfer.swift
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
* An InTransfer represents a data transfer from a remote peer to the local peer. The connection class generates InTransfer instances when a remote peer sends data.
*/
open class InTransfer: Transfer {
    // MARK: Events

    // Called when the transfer completes with the full data received. Buffers the data in memory until the transfer is complete. Alternative to onPartialData. If both are set, onPartialData is used.
    open var onCompleteData: ((Transfer, Data) -> Void)?
    // Called whenever data is received. This method may be called multiple times, i.e. the data is not the full transfer. Exclusive alternative to onCompleteData.
    open var onPartialData: ((Transfer, Data) -> Void)?

    // MARK: Internal
    func updateWithReceivedData(_ data: Data) {
        if let onPartialData = self.onPartialData {
            onPartialData(self, data)
        } else if self.onCompleteData != nil {
            if self.dataBuffer == nil { self.dataBuffer = NSMutableData(capacity: self.length) }
            dataBuffer?.append(data)
        } else {
            log(.high, error: "You need to set either onCompleteData or onPartialData on incoming transfers (affected instance: \(self))")
        }
        if onCompleteData != nil && onPartialData != nil { log(.medium, warning: "You set both onCompleteData and onPartialData in \(self). Only onPartialData will be used.") }

        self.updateProgress(data.count)
    }

    var dataBuffer: NSMutableData?

    override open func cancel() {
        self.manager?.cancel(self)
    }
    override func confirmEnd() {
        self.dataBuffer = nil

        self.onCompleteData = nil
        self.onPartialData = nil

        super.confirmEnd()
    }
    override func confirmCompletion() {
        if let data = self.dataBuffer { self.onCompleteData?(self, data as Data) }

        super.confirmCompletion()
    }
}
