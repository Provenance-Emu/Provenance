//
//  PVSQLiteDatabase.swift
//
//
//  Created by Joseph Mattiello on 1/20/23.
//

import Foundation
import SQLite

package typealias SQLQueryDict = [String: AnyObject]
package typealias SQLQueryResponse = [SQLQueryDict]
package protocol SQLQueryable {
    func execute(query: String) throws -> SQLQueryResponse
}

public struct PVSQLiteDatabase {
    package let url: URL
    package let connection: SQLite.Connection

    public init(withURL url: URL) throws {
        self.url = url
        let connection = try SQLite.Connection(url.path, readonly: true)
        self.connection = connection
    }
}

extension PVSQLiteDatabase: SQLQueryable {
    package func execute(query: String) throws -> SQLQueryResponse {
        var result = SQLQueryResponse()

        // prepare connection, sql, inout statement
        // try connection.execute(query)
        let stmt = try connection.prepare(query)
        for row in stmt {
            var dict = SQLQueryDict()
            for (index, name) in stmt.columnNames.enumerated() {
                dict[name] = row[index] as AnyObject
            }
            result.append(dict)
        }
        return result
    }
}
