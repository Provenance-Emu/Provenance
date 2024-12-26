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
    func execute(query: String, parameters: [Any]?) throws -> SQLQueryResponse
}

public struct PVSQLiteDatabase: @unchecked Sendable {
    package let url: URL
    package let connection: SQLite.Connection

    public init(withURL url: URL) throws {
        self.url = url
        let connection = try SQLite.Connection(url.path, readonly: true)
        self.connection = connection
    }
}

extension PVSQLiteDatabase: SQLQueryable {
    package func execute(query: String, parameters: [Any]? = nil) throws -> SQLQueryResponse {
        var result = SQLQueryResponse()
        let stmt = try connection.prepare(query)

        // Bind parameters if provided
        if let params = parameters {
            // Convert parameters to SQLite.Binding types
            let bindings: [SQLite.Binding?] = params.map { param in
                switch param {
                case let text as String:
                    return text
                case let number as Int64:
                    return number
                case let number as Int:
                    return Int64(number)
                case let number as Double:
                    return number
                case let data as Data:
                    return Blob(bytes: [UInt8](data))
                case let bool as Bool:
                    return bool
                case is NSNull:
                    return nil
                default:
                    return String(describing: param)
                }
            }

            // Bind all parameters at once
            _ = stmt.bind(bindings)
        }

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
