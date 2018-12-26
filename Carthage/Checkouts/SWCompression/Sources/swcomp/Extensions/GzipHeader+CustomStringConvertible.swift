// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import SWCompression

extension GzipHeader: CustomStringConvertible {

    public var description: String {
        var output = """
        File name: \(self.fileName ?? "")
        File system type: \(self.osType)
        Compression method: \(self.compressionMethod)

        """
        if let mtime = self.modificationTime {
            output += "Modification time: \(mtime)\n"
        }
        if let comment = self.comment {
            output += "Comment: \(comment)\n"
        }
        output += "Is text file: \(self.isTextFile)"
        return output
    }

}
