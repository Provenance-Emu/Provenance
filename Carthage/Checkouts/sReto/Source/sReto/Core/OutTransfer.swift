//
//  OutTransfer.swift
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
* An OutTransfer represents a data transfer from the local peer to a remote peer. You can obtain one by calling the connection's send method.
*/
open class OutTransfer: Transfer {
    open let dataProvider: (_ range: Range<Data.Index>) -> Data

    init(manager: TransferManager, dataLength: Int, dataProvider: @escaping (_ range: Range<Data.Index>) -> Data, identifier: UUID) {
        self.dataProvider = dataProvider
        super.init(manager: manager, length: dataLength, identifier: identifier)
    }

    func nextPacket(_ length: Int) -> DataPacket {
        let dataLength = min(self.length - self.progress, length - 4)
        //TODO: is that correct?
        let range = Range<Data.Index>(uncheckedBounds:(lower:progress, upper: progress + dataLength))
        let packet = DataPacket(data: self.dataProvider(range))
        self.progress += dataLength
        return packet
    }

    open override func cancel() {
        self.manager?.cancel(self)
    }
}
