import Foundation
import SQLite3
import PVSupport
import PVLogging

@objc
public enum OESQLiteDatabaseError: Error {
    case openError(Int32)
    case prepareError(Int32)
    case stepError(Int32)
    case bindError(Int32)
    case finalizeError(Int32)
    case journalModeError(Int32)
}

@objc
public typealias OESQLiteRow = [[String:AnyObject]]

@objc
public final class OESQLiteDatabase: NSObject {
    // private var connection: OESQLiteConnection
    private var connection: sqlite3?

    // public convenience init(withURL url: URL) throws {
    //     try self.init(withURL: url, readOnly: false)
    // }

    // public convenience init(withURL url: URL, readOnly: Bool) throws {
    //     try self.init(withURL: url, readOnly: readOnly, journalMode: .delete)
    // }

    // public init(withURL url: URL, readOnly: Bool, journalMode: OESQLiteDatabaseJournalMode) throws {
    //     let flags: Int32 = readOnly ? SQLITE_OPEN_READONLY : SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE
    //     let status = sqlite3_open_v2(url.path, &db, flags, nil)
    //     guard status == SQLITE_OK else {
    //         throw OESQLiteDatabaseError.openError(status)
    //     }

    //     try setJournalMode(journalMode)
    // }
    public required init(withURL url: URL, readOnly: Bool, journalMode: OESQLiteDatabaseJournalMode) throws {
        var db: OpaquePointer?
        let flags: Int32 = readOnly ? SQLITE_OPEN_READONLY : SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE
        let status = sqlite3_open_v2(url.path, &db, flags, nil)
        guard status == SQLITE_OK else {
            throw OESQLiteDatabaseError.openError(status)
        }

        try setJournalMode(journalMode)
        connection = db
    }

    deinit {
        let result = sqlite3_close(connection)
        if result != SQLITE_OK {
            ELOG("Error closing database: \(result). \(String(cString: sqlite3_errmsg(connection)))")
        }
    }

    // public func execute(query sql: String) throws -> [OESQLiteRow] {
    //     var statement: OESQLiteStatement?
    //     try prepare(sql, statement: &statement)
    //     defer { statement?.finalize() }

    //     var rows = [OESQLiteRow]()
    //     while statement?.step() == .row {
    //         rows.append(statement!.row)
    //     }

    //     return rows
    // }

    public func execute(query sql: String) throws -> [OESQLiteRow] {
       var result: [OESQLiteRow] = []
       var sql_err: SQLiteError = .ok
       let csql = sql.cString(using: .utf8)

       sql_err = sqlite3_prepare_v2(connection, csql, -1, &stmt, nil)
         if sql_err != .ok {
            sqlite3_finalize(stmt)
              throw OESQLiteDatabaseError.prepareError(sql_err.rawValue)
         }

         while (sqlite3_step(stmt) == SQLITE_ROW) {
              var row: [String:AnyObject] = [:]
              let columnCount = sqlite3_column_count(stmt)
              for i in 0..<columnCount {
                let name = String(cString: sqlite3_column_name(stmt, i))
                let value = _value(ofSQLStatement: stmt, atColumn: i)
                row[name] = value as AnyObject
              }
              result.append(row)
         }
         sqlite3_finalize(stmt)
         return result
    }

    private func _value(ofSQLStatement stmt: sqlite3_stmt, atColumn column: Int) -> Any {
        let type = sqlite3_column_type(stmt, Int32(column))
        switch type {
        case SQLITE_INTEGER:
            return sqlite3_column_int64(stmt, Int32(column))
        case SQLITE_FLOAT:
            return sqlite3_column_double(stmt, Int32(column))
        case SQLITE_TEXT:
            let text = sqlite3_column_text(stmt, Int32(column))
            return String(cString: text!)
        case SQLITE_BLOB:
            let bytes = sqlite3_column_blob(stmt, Int32(column))
            let length = sqlite3_column_bytes(stmt, Int32(column))
            return Data(bytes: bytes!, count: Int(length))
        case SQLITE_NULL:
            return NSNull()
        default:
            fatalError("Unknown column type: \(type)")
        }
    }
}
