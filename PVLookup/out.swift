// Autocreated by sqlite2swift at 2024-10-20T17:58:02Z

import SQLite3
import Foundation
import Lighter

/**
 * Create a SQLite3 database
 * 
 * The database is created using the SQL `create` statements in the
 * Schema structures.
 * 
 * If the operation is successful, the open database handle will be
 * returned in the `db` `inout` parameter.
 * If the open succeeds, but the SQL execution fails, an incomplete
 * database can be left behind. I.e. if an error happens, the path
 * should be tested and deleted if appropriate.
 * 
 * Example:
 * ```swift
 * var db : OpaquePointer!
 * let rc = sqlite3_create_shiragameschema(path, &db)
 * ```
 * 
 * - Parameters:
 *   - path: Path of the database.
 *   - flags: Custom open flags.
 *   - db: A SQLite3 database handle, if successful.
 * - Returns: The SQLite3 error code (`SQLITE_OK` on success).
 */
@inlinable
public func sqlite3_create_shiragameschema(
  _ path: UnsafePointer<CChar>!,
  _ flags: Int32 = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE,
  _ db: inout OpaquePointer?
) -> Int32
{
  let openrc = sqlite3_open_v2(path, &db, flags, nil)
  if openrc != SQLITE_OK {
    return openrc
  }
  let execrc = sqlite3_exec(db, ShiragameSchema.creationSQL, nil, nil, nil)
  if execrc != SQLITE_OK {
    sqlite3_close(db)
    db = nil
    return execrc
  }
  return SQLITE_OK
}

/**
 * Insert a ``Game`` record in the SQLite database.
 * 
 * This operates on a raw SQLite database handle (as returned by
 * `sqlite3_open`).
 * 
 * Example:
 * ```swift
 * let rc = sqlite3_game_insert(db, record)
 * assert(rc == SQLITE_OK)
 * ```
 * 
 * - Parameters:
 *   - db: SQLite3 database handle.
 *   - record: The record to insert. Updated with the actual table values (e.g. assigned primary key).
 * - Returns: The SQLite error code (of `sqlite3_prepare/step`), e.g. `SQLITE_OK`.
 */
@inlinable
@discardableResult
public func sqlite3_game_insert(_ db: OpaquePointer!, _ record: inout Game) -> Int32
{
  let sql = ShiragameSchema.useInsertReturning ? Game.Schema.insertReturning : Game.Schema.insert
  var handle : OpaquePointer? = nil
  guard sqlite3_prepare_v2(db, sql, -1, &handle, nil) == SQLITE_OK,
        let statement = handle else { return sqlite3_errcode(db) }
  defer { sqlite3_finalize(statement) }
  return record.bind(to: statement, indices: Game.Schema.insertParameterIndices) {
    let rc = sqlite3_step(statement)
    if rc == SQLITE_DONE {
      var sql = Game.Schema.select
      sql.append(#" WHERE ROWID = last_insert_rowid()"#)
      var handle : OpaquePointer? = nil
      guard sqlite3_prepare_v2(db, sql, -1, &handle, nil) == SQLITE_OK,
            let statement = handle else { return sqlite3_errcode(db) }
      defer { sqlite3_finalize(statement) }
      let rc = sqlite3_step(statement)
      if rc == SQLITE_DONE {
        return SQLITE_OK
      }
      else if rc != SQLITE_ROW {
        return sqlite3_errcode(db)
      }
      record = Game(statement, indices: Game.Schema.selectColumnIndices)
      return SQLITE_OK
    }
    else if rc != SQLITE_ROW {
      return sqlite3_errcode(db)
    }
    record = Game(statement, indices: Game.Schema.selectColumnIndices)
    return SQLITE_OK
  }
}

/**
 * Update a ``Game`` record in the SQLite database.
 * 
 * This operates on a raw SQLite database handle (as returned by
 * `sqlite3_open`).
 * 
 * Example:
 * ```swift
 * let rc = sqlite3_game_update(db, record)
 * assert(rc == SQLITE_OK)
 * ```
 * 
 * - Parameters:
 *   - db: SQLite3 database handle.
 *   - record: The ``Game`` record to update.
 * - Returns: The SQLite error code (of `sqlite3_prepare/step`), e.g. `SQLITE_OK`.
 */
@inlinable
@discardableResult
public func sqlite3_game_update(_ db: OpaquePointer!, _ record: Game) -> Int32
{
  let sql = Game.Schema.update
  var handle : OpaquePointer? = nil
  guard sqlite3_prepare_v2(db, sql, -1, &handle, nil) == SQLITE_OK,
        let statement = handle else { return sqlite3_errcode(db) }
  defer { sqlite3_finalize(statement) }
  return record.bind(to: statement, indices: Game.Schema.updateParameterIndices) {
    let rc = sqlite3_step(statement)
    return rc != SQLITE_DONE && rc != SQLITE_ROW ? sqlite3_errcode(db) : SQLITE_OK
  }
}

/**
 * Delete a ``Game`` record in the SQLite database.
 * 
 * This operates on a raw SQLite database handle (as returned by
 * `sqlite3_open`).
 * 
 * Example:
 * ```swift
 * let rc = sqlite3_game_delete(db, record)
 * assert(rc == SQLITE_OK)
 * ```
 * 
 * - Parameters:
 *   - db: SQLite3 database handle.
 *   - record: The ``Game`` record to delete.
 * - Returns: The SQLite error code (of `sqlite3_prepare/step`), e.g. `SQLITE_OK`.
 */
@inlinable
@discardableResult
public func sqlite3_game_delete(_ db: OpaquePointer!, _ record: Game) -> Int32
{
  let sql = Game.Schema.delete
  var handle : OpaquePointer? = nil
  guard sqlite3_prepare_v2(db, sql, -1, &handle, nil) == SQLITE_OK,
        let statement = handle else { return sqlite3_errcode(db) }
  defer { sqlite3_finalize(statement) }
  return record.bind(to: statement, indices: Game.Schema.deleteParameterIndices) {
    let rc = sqlite3_step(statement)
    return rc != SQLITE_DONE && rc != SQLITE_ROW ? sqlite3_errcode(db) : SQLITE_OK
  }
}

/**
 * Fetch ``Game`` records, filtering using a Swift closure.
 * 
 * This is fetching full ``Game`` records from the passed in SQLite database
 * handle. The filtering is done within SQLite, but using a Swift closure
 * that can be passed in.
 * 
 * Within that closure other SQL queries can be done on separate connections,
 * but *not* within the same database handle that is being passed in (because
 * the closure is executed in the context of the query).
 * 
 * Sorting can be done using raw SQL (by passing in a `orderBy` parameter,
 * e.g. `orderBy: "name DESC"`),
 * or just in Swift (e.g. `fetch(in: db).sorted { $0.name > $1.name }`).
 * Since the matching is done in Swift anyways, the primary advantage of
 * doing it in SQL is that a `LIMIT` can be applied efficiently (i.e. w/o
 * walking and loading all rows).
 * 
 * If the function returns `nil`, the error can be found using the usual
 * `sqlite3_errcode` and companions.
 * 
 * Example:
 * ```swift
 * let records = sqlite3_games_fetch(db) { record in
 *   record.name != "Duck"
 * }
 * 
 * let records = sqlite3_games_fetch(db, orderBy: "name", limit: 5) {
 *   $0.firstname != nil
 * }
 * ```
 * 
 * - Parameters:
 *   - db: The SQLite database handle (as returned by `sqlite3_open`)
 *   - sql: Optional custom SQL yielding ``Game`` records.
 *   - orderBySQL: If set, some SQL that is added as an `ORDER BY` clause (e.g. `name DESC`).
 *   - limit: An optional fetch limit.
 *   - filter: A Swift closure used for filtering, taking the``Game`` record to be matched.
 * - Returns: The records matching the query, or `nil` if there was an error.
 */
@inlinable
public func sqlite3_games_fetch(
  _ db: OpaquePointer!,
  sql customSQL: String? = nil,
  orderBy orderBySQL: String? = nil,
  limit: Int? = nil,
  filter: @escaping ( Game ) -> Bool
) -> [ Game ]?
{
  withUnsafePointer(to: filter) { ( closurePtr ) in
    guard Game.Schema.registerSwiftMatcher(in: db, flags: SQLITE_UTF8, matcher: closurePtr) == SQLITE_OK else {
      return nil
    }
    defer {
      Game.Schema.unregisterSwiftMatcher(in: db, flags: SQLITE_UTF8)
    }
    var sql = customSQL ?? Game.Schema.matchSelect
    if let orderBySQL = orderBySQL {
      sql.append(" ORDER BY \(orderBySQL)")
    }
    if let limit = limit {
      sql.append(" LIMIT \(limit)")
    }
    var handle : OpaquePointer? = nil
    guard sqlite3_prepare_v2(db, sql, -1, &handle, nil) == SQLITE_OK,
          let statement = handle else { return nil }
    defer { sqlite3_finalize(statement) }
    let indices = customSQL != nil ? Game.Schema.lookupColumnIndices(in: statement) : Game.Schema.selectColumnIndices
    var records = [ Game ]()
    while true {
      let rc = sqlite3_step(statement)
      if rc == SQLITE_DONE {
        break
      }
      else if rc != SQLITE_ROW {
        return nil
      }
      records.append(Game(statement, indices: indices))
    }
    return records
  }
}

/**
 * Fetch ``Game`` records using the base SQLite API.
 * 
 * If the function returns `nil`, the error can be found using the usual
 * `sqlite3_errcode` and companions.
 * 
 * Example:
 * ```swift
 * let records = sqlite3_games_fetch(
 *   db, sql: #"SELECT * FROM game"#
 * }
 * 
 * let records = sqlite3_games_fetch(
 *   db, sql: #"SELECT * FROM game"#,
 *   orderBy: "name", limit: 5
 * )
 * ```
 * 
 * - Parameters:
 *   - db: The SQLite database handle (as returned by `sqlite3_open`)
 *   - sql: Custom SQL yielding ``Game`` records.
 *   - orderBySQL: If set, some SQL that is added as an `ORDER BY` clause (e.g. `name DESC`).
 *   - limit: An optional fetch limit.
 * - Returns: The records matching the query, or `nil` if there was an error.
 */
@inlinable
public func sqlite3_games_fetch(
  _ db: OpaquePointer!,
  sql customSQL: String? = nil,
  orderBy orderBySQL: String? = nil,
  limit: Int? = nil
) -> [ Game ]?
{
  var sql = customSQL ?? Game.Schema.select
  if let orderBySQL = orderBySQL {
    sql.append(" ORDER BY \(orderBySQL)")
  }
  if let limit = limit {
    sql.append(" LIMIT \(limit)")
  }
  var handle : OpaquePointer? = nil
  guard sqlite3_prepare_v2(db, sql, -1, &handle, nil) == SQLITE_OK,
        let statement = handle else { return nil }
  defer { sqlite3_finalize(statement) }
  let indices = customSQL != nil ? Game.Schema.lookupColumnIndices(in: statement) : Game.Schema.selectColumnIndices
  var records = [ Game ]()
  while true {
    let rc = sqlite3_step(statement)
    if rc == SQLITE_DONE {
      break
    }
    else if rc != SQLITE_ROW {
      return nil
    }
    records.append(Game(statement, indices: indices))
  }
  return records
}

/**
 * Fetches the ``Rom`` records related to a ``Game`` (`gameId`).
 * 
 * This fetches the related ``Rom`` records using the
 * ``Rom/gameId`` property.
 * 
 * Example:
 * ```swift
 * let record         : Game = ...
 * let relatedRecords = sqlite3_roms_fetch(db, for: record)
 * ```
 * 
 * - Parameters:
 *   - db: The SQLite database handle (as returned by `sqlite3_open`)
 *   - record: The ``Game`` record.
 *   - orderBySQL: If set, some SQL that is added as an `ORDER BY` clause (e.g. `name DESC`).
 *   - limit: An optional fetch limit.
 * - Returns: The related ``Rom`` records.
 */
@inlinable
public func sqlite3_roms_fetch(
  _ db: OpaquePointer!,
  `for` record: Game,
  orderBy orderBySQL: String? = nil,
  limit: Int? = nil
) -> [ Rom ]?
{
  var sql = Rom.Schema.select
  sql.append(#" WHERE "game_id" = ? LIMIT 1"#)
  if let orderBySQL = orderBySQL {
    sql.append(" ORDER BY \(orderBySQL)")
  }
  if let limit = limit {
    sql.append(" LIMIT \(limit)")
  }
  var handle : OpaquePointer? = nil
  guard sqlite3_prepare_v2(db, sql, -1, &handle, nil) == SQLITE_OK,
        let statement = handle else { return nil }
  defer { sqlite3_finalize(statement) }
  if let fkey = record.id {
    sqlite3_bind_int64(statement, 1, Int64(fkey))
  }
  else {
    sqlite3_bind_null(statement, 1)
  }
  let indices = Rom.Schema.selectColumnIndices
  var records = [ Rom ]()
  while true {
    let rc = sqlite3_step(statement)
    if rc == SQLITE_DONE {
      break
    }
    else if rc != SQLITE_ROW {
      return nil
    }
    records.append(Rom(statement, indices: indices))
  }
  return records
}

/**
 * Fetches the ``Serial`` records related to a ``Game`` (`gameId`).
 * 
 * This fetches the related ``Serial`` records using the
 * ``Serial/gameId`` property.
 * 
 * Example:
 * ```swift
 * let record         : Game = ...
 * let relatedRecords = sqlite3_serials_fetch(db, for: record)
 * ```
 * 
 * - Parameters:
 *   - db: The SQLite database handle (as returned by `sqlite3_open`)
 *   - record: The ``Game`` record.
 *   - orderBySQL: If set, some SQL that is added as an `ORDER BY` clause (e.g. `name DESC`).
 *   - limit: An optional fetch limit.
 * - Returns: The related ``Serial`` records.
 */
@inlinable
public func sqlite3_serials_fetch(
  _ db: OpaquePointer!,
  `for` record: Game,
  orderBy orderBySQL: String? = nil,
  limit: Int? = nil
) -> [ Serial ]?
{
  var sql = Serial.Schema.select
  sql.append(#" WHERE "game_id" = ? LIMIT 1"#)
  if let orderBySQL = orderBySQL {
    sql.append(" ORDER BY \(orderBySQL)")
  }
  if let limit = limit {
    sql.append(" LIMIT \(limit)")
  }
  var handle : OpaquePointer? = nil
  guard sqlite3_prepare_v2(db, sql, -1, &handle, nil) == SQLITE_OK,
        let statement = handle else { return nil }
  defer { sqlite3_finalize(statement) }
  if let fkey = record.id {
    sqlite3_bind_int64(statement, 1, Int64(fkey))
  }
  else {
    sqlite3_bind_null(statement, 1)
  }
  let indices = Serial.Schema.selectColumnIndices
  var records = [ Serial ]()
  while true {
    let rc = sqlite3_step(statement)
    if rc == SQLITE_DONE {
      break
    }
    else if rc != SQLITE_ROW {
      return nil
    }
    records.append(Serial(statement, indices: indices))
  }
  return records
}

/**
 * Insert a ``Rom`` record in the SQLite database.
 * 
 * This operates on a raw SQLite database handle (as returned by
 * `sqlite3_open`).
 * 
 * Example:
 * ```swift
 * let rc = sqlite3_rom_insert(db, record)
 * assert(rc == SQLITE_OK)
 * ```
 * 
 * - Parameters:
 *   - db: SQLite3 database handle.
 *   - record: The record to insert. Updated with the actual table values (e.g. assigned primary key).
 * - Returns: The SQLite error code (of `sqlite3_prepare/step`), e.g. `SQLITE_OK`.
 */
@inlinable
@discardableResult
public func sqlite3_rom_insert(_ db: OpaquePointer!, _ record: inout Rom) -> Int32
{
  let sql = ShiragameSchema.useInsertReturning ? Rom.Schema.insertReturning : Rom.Schema.insert
  var handle : OpaquePointer? = nil
  guard sqlite3_prepare_v2(db, sql, -1, &handle, nil) == SQLITE_OK,
        let statement = handle else { return sqlite3_errcode(db) }
  defer { sqlite3_finalize(statement) }
  return record.bind(to: statement, indices: Rom.Schema.insertParameterIndices) {
    let rc = sqlite3_step(statement)
    if rc == SQLITE_DONE {
      var sql = Rom.Schema.select
      sql.append(#" WHERE ROWID = last_insert_rowid()"#)
      var handle : OpaquePointer? = nil
      guard sqlite3_prepare_v2(db, sql, -1, &handle, nil) == SQLITE_OK,
            let statement = handle else { return sqlite3_errcode(db) }
      defer { sqlite3_finalize(statement) }
      let rc = sqlite3_step(statement)
      if rc == SQLITE_DONE {
        return SQLITE_OK
      }
      else if rc != SQLITE_ROW {
        return sqlite3_errcode(db)
      }
      record = Rom(statement, indices: Rom.Schema.selectColumnIndices)
      return SQLITE_OK
    }
    else if rc != SQLITE_ROW {
      return sqlite3_errcode(db)
    }
    record = Rom(statement, indices: Rom.Schema.selectColumnIndices)
    return SQLITE_OK
  }
}

/**
 * Delete a ``Rom`` record in the SQLite database.
 * 
 * This operates on a raw SQLite database handle (as returned by
 * `sqlite3_open`).
 * 
 * Example:
 * ```swift
 * let rc = sqlite3_rom_delete(db, record)
 * assert(rc == SQLITE_OK)
 * ```
 * 
 * - Parameters:
 *   - db: SQLite3 database handle.
 *   - record: The ``Rom`` record to delete.
 * - Returns: The SQLite error code (of `sqlite3_prepare/step`), e.g. `SQLITE_OK`.
 */
@inlinable
@discardableResult
public func sqlite3_rom_delete(_ db: OpaquePointer!, _ record: Rom) -> Int32
{
  let sql = Rom.Schema.delete
  var handle : OpaquePointer? = nil
  guard sqlite3_prepare_v2(db, sql, -1, &handle, nil) == SQLITE_OK,
        let statement = handle else { return sqlite3_errcode(db) }
  defer { sqlite3_finalize(statement) }
  return record.bind(to: statement, indices: Rom.Schema.deleteParameterIndices) {
    let rc = sqlite3_step(statement)
    return rc != SQLITE_DONE && rc != SQLITE_ROW ? sqlite3_errcode(db) : SQLITE_OK
  }
}

/**
 * Fetch ``Rom`` records, filtering using a Swift closure.
 * 
 * This is fetching full ``Rom`` records from the passed in SQLite database
 * handle. The filtering is done within SQLite, but using a Swift closure
 * that can be passed in.
 * 
 * Within that closure other SQL queries can be done on separate connections,
 * but *not* within the same database handle that is being passed in (because
 * the closure is executed in the context of the query).
 * 
 * Sorting can be done using raw SQL (by passing in a `orderBy` parameter,
 * e.g. `orderBy: "name DESC"`),
 * or just in Swift (e.g. `fetch(in: db).sorted { $0.name > $1.name }`).
 * Since the matching is done in Swift anyways, the primary advantage of
 * doing it in SQL is that a `LIMIT` can be applied efficiently (i.e. w/o
 * walking and loading all rows).
 * 
 * If the function returns `nil`, the error can be found using the usual
 * `sqlite3_errcode` and companions.
 * 
 * Example:
 * ```swift
 * let records = sqlite3_roms_fetch(db) { record in
 *   record.name != "Duck"
 * }
 * 
 * let records = sqlite3_roms_fetch(db, orderBy: "name", limit: 5) {
 *   $0.firstname != nil
 * }
 * ```
 * 
 * - Parameters:
 *   - db: The SQLite database handle (as returned by `sqlite3_open`)
 *   - sql: Optional custom SQL yielding ``Rom`` records.
 *   - orderBySQL: If set, some SQL that is added as an `ORDER BY` clause (e.g. `name DESC`).
 *   - limit: An optional fetch limit.
 *   - filter: A Swift closure used for filtering, taking the``Rom`` record to be matched.
 * - Returns: The records matching the query, or `nil` if there was an error.
 */
@inlinable
public func sqlite3_roms_fetch(
  _ db: OpaquePointer!,
  sql customSQL: String? = nil,
  orderBy orderBySQL: String? = nil,
  limit: Int? = nil,
  filter: @escaping ( Rom ) -> Bool
) -> [ Rom ]?
{
  withUnsafePointer(to: filter) { ( closurePtr ) in
    guard Rom.Schema.registerSwiftMatcher(in: db, flags: SQLITE_UTF8, matcher: closurePtr) == SQLITE_OK else {
      return nil
    }
    defer {
      Rom.Schema.unregisterSwiftMatcher(in: db, flags: SQLITE_UTF8)
    }
    var sql = customSQL ?? Rom.Schema.matchSelect
    if let orderBySQL = orderBySQL {
      sql.append(" ORDER BY \(orderBySQL)")
    }
    if let limit = limit {
      sql.append(" LIMIT \(limit)")
    }
    var handle : OpaquePointer? = nil
    guard sqlite3_prepare_v2(db, sql, -1, &handle, nil) == SQLITE_OK,
          let statement = handle else { return nil }
    defer { sqlite3_finalize(statement) }
    let indices = customSQL != nil ? Rom.Schema.lookupColumnIndices(in: statement) : Rom.Schema.selectColumnIndices
    var records = [ Rom ]()
    while true {
      let rc = sqlite3_step(statement)
      if rc == SQLITE_DONE {
        break
      }
      else if rc != SQLITE_ROW {
        return nil
      }
      records.append(Rom(statement, indices: indices))
    }
    return records
  }
}

/**
 * Fetch ``Rom`` records using the base SQLite API.
 * 
 * If the function returns `nil`, the error can be found using the usual
 * `sqlite3_errcode` and companions.
 * 
 * Example:
 * ```swift
 * let records = sqlite3_roms_fetch(
 *   db, sql: #"SELECT * FROM rom"#
 * }
 * 
 * let records = sqlite3_roms_fetch(
 *   db, sql: #"SELECT * FROM rom"#,
 *   orderBy: "name", limit: 5
 * )
 * ```
 * 
 * - Parameters:
 *   - db: The SQLite database handle (as returned by `sqlite3_open`)
 *   - sql: Custom SQL yielding ``Rom`` records.
 *   - orderBySQL: If set, some SQL that is added as an `ORDER BY` clause (e.g. `name DESC`).
 *   - limit: An optional fetch limit.
 * - Returns: The records matching the query, or `nil` if there was an error.
 */
@inlinable
public func sqlite3_roms_fetch(
  _ db: OpaquePointer!,
  sql customSQL: String? = nil,
  orderBy orderBySQL: String? = nil,
  limit: Int? = nil
) -> [ Rom ]?
{
  var sql = customSQL ?? Rom.Schema.select
  if let orderBySQL = orderBySQL {
    sql.append(" ORDER BY \(orderBySQL)")
  }
  if let limit = limit {
    sql.append(" LIMIT \(limit)")
  }
  var handle : OpaquePointer? = nil
  guard sqlite3_prepare_v2(db, sql, -1, &handle, nil) == SQLITE_OK,
        let statement = handle else { return nil }
  defer { sqlite3_finalize(statement) }
  let indices = customSQL != nil ? Rom.Schema.lookupColumnIndices(in: statement) : Rom.Schema.selectColumnIndices
  var records = [ Rom ]()
  while true {
    let rc = sqlite3_step(statement)
    if rc == SQLITE_DONE {
      break
    }
    else if rc != SQLITE_ROW {
      return nil
    }
    records.append(Rom(statement, indices: indices))
  }
  return records
}

/**
 * Fetch the ``Game`` record related to an ``Rom`` (`gameId`).
 * 
 * This fetches the related ``Game`` record using the
 * ``Rom/gameId`` property.
 * 
 * Example:
 * ```swift
 * let sourceRecord  : Rom = ...
 * let relatedRecord = sqlite3_game_find(db, for: sourceRecord)
 * ```
 * 
 * - Parameters:
 *   - db: The SQLite database handle (as returned by `sqlite3_open`)
 *   - record: The ``Rom`` record.
 * - Returns: The related ``Game`` record, or `nil` if not found/error.
 */
@inlinable
public func sqlite3_game_find(_ db: OpaquePointer!, `for` record: Rom) -> Game?
{
  var sql = Game.Schema.select
  sql.append(#" WHERE "game_id" = ? LIMIT 1"#)
  var handle : OpaquePointer? = nil
  guard sqlite3_prepare_v2(db, sql, -1, &handle, nil) == SQLITE_OK,
        let statement = handle else { return nil }
  defer { sqlite3_finalize(statement) }
  sqlite3_bind_int64(statement, 1, Int64(record.gameId))
  let rc = sqlite3_step(statement)
  if rc == SQLITE_DONE {
    return nil
  }
  else if rc != SQLITE_ROW {
    return nil
  }
  let indices = Game.Schema.selectColumnIndices
  return Game(statement, indices: indices)
}

/**
 * Insert a ``Serial`` record in the SQLite database.
 * 
 * This operates on a raw SQLite database handle (as returned by
 * `sqlite3_open`).
 * 
 * Example:
 * ```swift
 * let rc = sqlite3_serial_insert(db, record)
 * assert(rc == SQLITE_OK)
 * ```
 * 
 * - Parameters:
 *   - db: SQLite3 database handle.
 *   - record: The record to insert. Updated with the actual table values (e.g. assigned primary key).
 * - Returns: The SQLite error code (of `sqlite3_prepare/step`), e.g. `SQLITE_OK`.
 */
@inlinable
@discardableResult
public func sqlite3_serial_insert(_ db: OpaquePointer!, _ record: inout Serial)
  -> Int32
{
  let sql = ShiragameSchema.useInsertReturning ? Serial.Schema.insertReturning : Serial.Schema.insert
  var handle : OpaquePointer? = nil
  guard sqlite3_prepare_v2(db, sql, -1, &handle, nil) == SQLITE_OK,
        let statement = handle else { return sqlite3_errcode(db) }
  defer { sqlite3_finalize(statement) }
  return record.bind(to: statement, indices: Serial.Schema.insertParameterIndices) {
    let rc = sqlite3_step(statement)
    if rc == SQLITE_DONE {
      var sql = Serial.Schema.select
      sql.append(#" WHERE ROWID = last_insert_rowid()"#)
      var handle : OpaquePointer? = nil
      guard sqlite3_prepare_v2(db, sql, -1, &handle, nil) == SQLITE_OK,
            let statement = handle else { return sqlite3_errcode(db) }
      defer { sqlite3_finalize(statement) }
      let rc = sqlite3_step(statement)
      if rc == SQLITE_DONE {
        return SQLITE_OK
      }
      else if rc != SQLITE_ROW {
        return sqlite3_errcode(db)
      }
      record = Serial(statement, indices: Serial.Schema.selectColumnIndices)
      return SQLITE_OK
    }
    else if rc != SQLITE_ROW {
      return sqlite3_errcode(db)
    }
    record = Serial(statement, indices: Serial.Schema.selectColumnIndices)
    return SQLITE_OK
  }
}

/**
 * Delete a ``Serial`` record in the SQLite database.
 * 
 * This operates on a raw SQLite database handle (as returned by
 * `sqlite3_open`).
 * 
 * Example:
 * ```swift
 * let rc = sqlite3_serial_delete(db, record)
 * assert(rc == SQLITE_OK)
 * ```
 * 
 * - Parameters:
 *   - db: SQLite3 database handle.
 *   - record: The ``Serial`` record to delete.
 * - Returns: The SQLite error code (of `sqlite3_prepare/step`), e.g. `SQLITE_OK`.
 */
@inlinable
@discardableResult
public func sqlite3_serial_delete(_ db: OpaquePointer!, _ record: Serial) -> Int32
{
  let sql = Serial.Schema.delete
  var handle : OpaquePointer? = nil
  guard sqlite3_prepare_v2(db, sql, -1, &handle, nil) == SQLITE_OK,
        let statement = handle else { return sqlite3_errcode(db) }
  defer { sqlite3_finalize(statement) }
  return record.bind(to: statement, indices: Serial.Schema.deleteParameterIndices) {
    let rc = sqlite3_step(statement)
    return rc != SQLITE_DONE && rc != SQLITE_ROW ? sqlite3_errcode(db) : SQLITE_OK
  }
}

/**
 * Fetch ``Serial`` records, filtering using a Swift closure.
 * 
 * This is fetching full ``Serial`` records from the passed in SQLite database
 * handle. The filtering is done within SQLite, but using a Swift closure
 * that can be passed in.
 * 
 * Within that closure other SQL queries can be done on separate connections,
 * but *not* within the same database handle that is being passed in (because
 * the closure is executed in the context of the query).
 * 
 * Sorting can be done using raw SQL (by passing in a `orderBy` parameter,
 * e.g. `orderBy: "name DESC"`),
 * or just in Swift (e.g. `fetch(in: db).sorted { $0.name > $1.name }`).
 * Since the matching is done in Swift anyways, the primary advantage of
 * doing it in SQL is that a `LIMIT` can be applied efficiently (i.e. w/o
 * walking and loading all rows).
 * 
 * If the function returns `nil`, the error can be found using the usual
 * `sqlite3_errcode` and companions.
 * 
 * Example:
 * ```swift
 * let records = sqlite3_serials_fetch(db) { record in
 *   record.name != "Duck"
 * }
 * 
 * let records = sqlite3_serials_fetch(db, orderBy: "name", limit: 5) {
 *   $0.firstname != nil
 * }
 * ```
 * 
 * - Parameters:
 *   - db: The SQLite database handle (as returned by `sqlite3_open`)
 *   - sql: Optional custom SQL yielding ``Serial`` records.
 *   - orderBySQL: If set, some SQL that is added as an `ORDER BY` clause (e.g. `name DESC`).
 *   - limit: An optional fetch limit.
 *   - filter: A Swift closure used for filtering, taking the``Serial`` record to be matched.
 * - Returns: The records matching the query, or `nil` if there was an error.
 */
@inlinable
public func sqlite3_serials_fetch(
  _ db: OpaquePointer!,
  sql customSQL: String? = nil,
  orderBy orderBySQL: String? = nil,
  limit: Int? = nil,
  filter: @escaping ( Serial ) -> Bool
) -> [ Serial ]?
{
  withUnsafePointer(to: filter) { ( closurePtr ) in
    guard Serial.Schema.registerSwiftMatcher(in: db, flags: SQLITE_UTF8, matcher: closurePtr) == SQLITE_OK else {
      return nil
    }
    defer {
      Serial.Schema.unregisterSwiftMatcher(in: db, flags: SQLITE_UTF8)
    }
    var sql = customSQL ?? Serial.Schema.matchSelect
    if let orderBySQL = orderBySQL {
      sql.append(" ORDER BY \(orderBySQL)")
    }
    if let limit = limit {
      sql.append(" LIMIT \(limit)")
    }
    var handle : OpaquePointer? = nil
    guard sqlite3_prepare_v2(db, sql, -1, &handle, nil) == SQLITE_OK,
          let statement = handle else { return nil }
    defer { sqlite3_finalize(statement) }
    let indices = customSQL != nil ? Serial.Schema.lookupColumnIndices(in: statement) : Serial.Schema.selectColumnIndices
    var records = [ Serial ]()
    while true {
      let rc = sqlite3_step(statement)
      if rc == SQLITE_DONE {
        break
      }
      else if rc != SQLITE_ROW {
        return nil
      }
      records.append(Serial(statement, indices: indices))
    }
    return records
  }
}

/**
 * Fetch ``Serial`` records using the base SQLite API.
 * 
 * If the function returns `nil`, the error can be found using the usual
 * `sqlite3_errcode` and companions.
 * 
 * Example:
 * ```swift
 * let records = sqlite3_serials_fetch(
 *   db, sql: #"SELECT * FROM serial"#
 * }
 * 
 * let records = sqlite3_serials_fetch(
 *   db, sql: #"SELECT * FROM serial"#,
 *   orderBy: "name", limit: 5
 * )
 * ```
 * 
 * - Parameters:
 *   - db: The SQLite database handle (as returned by `sqlite3_open`)
 *   - sql: Custom SQL yielding ``Serial`` records.
 *   - orderBySQL: If set, some SQL that is added as an `ORDER BY` clause (e.g. `name DESC`).
 *   - limit: An optional fetch limit.
 * - Returns: The records matching the query, or `nil` if there was an error.
 */
@inlinable
public func sqlite3_serials_fetch(
  _ db: OpaquePointer!,
  sql customSQL: String? = nil,
  orderBy orderBySQL: String? = nil,
  limit: Int? = nil
) -> [ Serial ]?
{
  var sql = customSQL ?? Serial.Schema.select
  if let orderBySQL = orderBySQL {
    sql.append(" ORDER BY \(orderBySQL)")
  }
  if let limit = limit {
    sql.append(" LIMIT \(limit)")
  }
  var handle : OpaquePointer? = nil
  guard sqlite3_prepare_v2(db, sql, -1, &handle, nil) == SQLITE_OK,
        let statement = handle else { return nil }
  defer { sqlite3_finalize(statement) }
  let indices = customSQL != nil ? Serial.Schema.lookupColumnIndices(in: statement) : Serial.Schema.selectColumnIndices
  var records = [ Serial ]()
  while true {
    let rc = sqlite3_step(statement)
    if rc == SQLITE_DONE {
      break
    }
    else if rc != SQLITE_ROW {
      return nil
    }
    records.append(Serial(statement, indices: indices))
  }
  return records
}

/**
 * Fetch the ``Game`` record related to an ``Serial`` (`gameId`).
 * 
 * This fetches the related ``Game`` record using the
 * ``Serial/gameId`` property.
 * 
 * Example:
 * ```swift
 * let sourceRecord  : Serial = ...
 * let relatedRecord = sqlite3_game_find(db, for: sourceRecord)
 * ```
 * 
 * - Parameters:
 *   - db: The SQLite database handle (as returned by `sqlite3_open`)
 *   - record: The ``Serial`` record.
 * - Returns: The related ``Game`` record, or `nil` if not found/error.
 */
@inlinable
public func sqlite3_game_find(_ db: OpaquePointer!, `for` record: Serial) -> Game?
{
  var sql = Game.Schema.select
  sql.append(#" WHERE "game_id" = ? LIMIT 1"#)
  var handle : OpaquePointer? = nil
  guard sqlite3_prepare_v2(db, sql, -1, &handle, nil) == SQLITE_OK,
        let statement = handle else { return nil }
  defer { sqlite3_finalize(statement) }
  sqlite3_bind_int64(statement, 1, Int64(record.gameId))
  let rc = sqlite3_step(statement)
  if rc == SQLITE_DONE {
    return nil
  }
  else if rc != SQLITE_ROW {
    return nil
  }
  let indices = Game.Schema.selectColumnIndices
  return Game(statement, indices: indices)
}

/**
 * Insert a ``Shiragame`` record in the SQLite database.
 * 
 * This operates on a raw SQLite database handle (as returned by
 * `sqlite3_open`).
 * 
 * Example:
 * ```swift
 * let rc = sqlite3_shiragame_insert(db, record)
 * assert(rc == SQLITE_OK)
 * ```
 * 
 * - Parameters:
 *   - db: SQLite3 database handle.
 *   - record: The record to insert. Updated with the actual table values (e.g. assigned primary key).
 * - Returns: The SQLite error code (of `sqlite3_prepare/step`), e.g. `SQLITE_OK`.
 */
@inlinable
@discardableResult
public func sqlite3_shiragame_insert(
  _ db: OpaquePointer!,
  _ record: inout Shiragame
) -> Int32
{
  let sql = ShiragameSchema.useInsertReturning ? Shiragame.Schema.insertReturning : Shiragame.Schema.insert
  var handle : OpaquePointer? = nil
  guard sqlite3_prepare_v2(db, sql, -1, &handle, nil) == SQLITE_OK,
        let statement = handle else { return sqlite3_errcode(db) }
  defer { sqlite3_finalize(statement) }
  return record.bind(to: statement, indices: Shiragame.Schema.insertParameterIndices) {
    let rc = sqlite3_step(statement)
    if rc == SQLITE_DONE {
      var sql = Shiragame.Schema.select
      sql.append(#" WHERE ROWID = last_insert_rowid()"#)
      var handle : OpaquePointer? = nil
      guard sqlite3_prepare_v2(db, sql, -1, &handle, nil) == SQLITE_OK,
            let statement = handle else { return sqlite3_errcode(db) }
      defer { sqlite3_finalize(statement) }
      let rc = sqlite3_step(statement)
      if rc == SQLITE_DONE {
        return SQLITE_OK
      }
      else if rc != SQLITE_ROW {
        return sqlite3_errcode(db)
      }
      record = Shiragame(statement, indices: Shiragame.Schema.selectColumnIndices)
      return SQLITE_OK
    }
    else if rc != SQLITE_ROW {
      return sqlite3_errcode(db)
    }
    record = Shiragame(statement, indices: Shiragame.Schema.selectColumnIndices)
    return SQLITE_OK
  }
}

/**
 * Delete a ``Shiragame`` record in the SQLite database.
 * 
 * This operates on a raw SQLite database handle (as returned by
 * `sqlite3_open`).
 * 
 * Example:
 * ```swift
 * let rc = sqlite3_shiragame_delete(db, record)
 * assert(rc == SQLITE_OK)
 * ```
 * 
 * - Parameters:
 *   - db: SQLite3 database handle.
 *   - record: The ``Shiragame`` record to delete.
 * - Returns: The SQLite error code (of `sqlite3_prepare/step`), e.g. `SQLITE_OK`.
 */
@inlinable
@discardableResult
public func sqlite3_shiragame_delete(_ db: OpaquePointer!, _ record: Shiragame)
  -> Int32
{
  let sql = Shiragame.Schema.delete
  var handle : OpaquePointer? = nil
  guard sqlite3_prepare_v2(db, sql, -1, &handle, nil) == SQLITE_OK,
        let statement = handle else { return sqlite3_errcode(db) }
  defer { sqlite3_finalize(statement) }
  return record.bind(to: statement, indices: Shiragame.Schema.deleteParameterIndices) {
    let rc = sqlite3_step(statement)
    return rc != SQLITE_DONE && rc != SQLITE_ROW ? sqlite3_errcode(db) : SQLITE_OK
  }
}

/**
 * Fetch ``Shiragame`` records, filtering using a Swift closure.
 * 
 * This is fetching full ``Shiragame`` records from the passed in SQLite database
 * handle. The filtering is done within SQLite, but using a Swift closure
 * that can be passed in.
 * 
 * Within that closure other SQL queries can be done on separate connections,
 * but *not* within the same database handle that is being passed in (because
 * the closure is executed in the context of the query).
 * 
 * Sorting can be done using raw SQL (by passing in a `orderBy` parameter,
 * e.g. `orderBy: "name DESC"`),
 * or just in Swift (e.g. `fetch(in: db).sorted { $0.name > $1.name }`).
 * Since the matching is done in Swift anyways, the primary advantage of
 * doing it in SQL is that a `LIMIT` can be applied efficiently (i.e. w/o
 * walking and loading all rows).
 * 
 * If the function returns `nil`, the error can be found using the usual
 * `sqlite3_errcode` and companions.
 * 
 * Example:
 * ```swift
 * let records = sqlite3_shiragames_fetch(db) { record in
 *   record.name != "Duck"
 * }
 * 
 * let records = sqlite3_shiragames_fetch(db, orderBy: "name", limit: 5) {
 *   $0.firstname != nil
 * }
 * ```
 * 
 * - Parameters:
 *   - db: The SQLite database handle (as returned by `sqlite3_open`)
 *   - sql: Optional custom SQL yielding ``Shiragame`` records.
 *   - orderBySQL: If set, some SQL that is added as an `ORDER BY` clause (e.g. `name DESC`).
 *   - limit: An optional fetch limit.
 *   - filter: A Swift closure used for filtering, taking the``Shiragame`` record to be matched.
 * - Returns: The records matching the query, or `nil` if there was an error.
 */
@inlinable
public func sqlite3_shiragames_fetch(
  _ db: OpaquePointer!,
  sql customSQL: String? = nil,
  orderBy orderBySQL: String? = nil,
  limit: Int? = nil,
  filter: @escaping ( Shiragame ) -> Bool
) -> [ Shiragame ]?
{
  withUnsafePointer(to: filter) { ( closurePtr ) in
    guard Shiragame.Schema.registerSwiftMatcher(
      in: db,
      flags: SQLITE_UTF8,
      matcher: closurePtr
    ) == SQLITE_OK else {
      return nil
    }
    defer {
      Shiragame.Schema.unregisterSwiftMatcher(in: db, flags: SQLITE_UTF8)
    }
    var sql = customSQL ?? Shiragame.Schema.matchSelect
    if let orderBySQL = orderBySQL {
      sql.append(" ORDER BY \(orderBySQL)")
    }
    if let limit = limit {
      sql.append(" LIMIT \(limit)")
    }
    var handle : OpaquePointer? = nil
    guard sqlite3_prepare_v2(db, sql, -1, &handle, nil) == SQLITE_OK,
          let statement = handle else { return nil }
    defer { sqlite3_finalize(statement) }
    let indices = customSQL != nil ? Shiragame.Schema.lookupColumnIndices(in: statement) : Shiragame.Schema.selectColumnIndices
    var records = [ Shiragame ]()
    while true {
      let rc = sqlite3_step(statement)
      if rc == SQLITE_DONE {
        break
      }
      else if rc != SQLITE_ROW {
        return nil
      }
      records.append(Shiragame(statement, indices: indices))
    }
    return records
  }
}

/**
 * Fetch ``Shiragame`` records using the base SQLite API.
 * 
 * If the function returns `nil`, the error can be found using the usual
 * `sqlite3_errcode` and companions.
 * 
 * Example:
 * ```swift
 * let records = sqlite3_shiragames_fetch(
 *   db, sql: #"SELECT * FROM shiragame"#
 * }
 * 
 * let records = sqlite3_shiragames_fetch(
 *   db, sql: #"SELECT * FROM shiragame"#,
 *   orderBy: "name", limit: 5
 * )
 * ```
 * 
 * - Parameters:
 *   - db: The SQLite database handle (as returned by `sqlite3_open`)
 *   - sql: Custom SQL yielding ``Shiragame`` records.
 *   - orderBySQL: If set, some SQL that is added as an `ORDER BY` clause (e.g. `name DESC`).
 *   - limit: An optional fetch limit.
 * - Returns: The records matching the query, or `nil` if there was an error.
 */
@inlinable
public func sqlite3_shiragames_fetch(
  _ db: OpaquePointer!,
  sql customSQL: String? = nil,
  orderBy orderBySQL: String? = nil,
  limit: Int? = nil
) -> [ Shiragame ]?
{
  var sql = customSQL ?? Shiragame.Schema.select
  if let orderBySQL = orderBySQL {
    sql.append(" ORDER BY \(orderBySQL)")
  }
  if let limit = limit {
    sql.append(" LIMIT \(limit)")
  }
  var handle : OpaquePointer? = nil
  guard sqlite3_prepare_v2(db, sql, -1, &handle, nil) == SQLITE_OK,
        let statement = handle else { return nil }
  defer { sqlite3_finalize(statement) }
  let indices = customSQL != nil ? Shiragame.Schema.lookupColumnIndices(in: statement) : Shiragame.Schema.selectColumnIndices
  var records = [ Shiragame ]()
  while true {
    let rc = sqlite3_step(statement)
    if rc == SQLITE_DONE {
      break
    }
    else if rc != SQLITE_ROW {
      return nil
    }
    records.append(Shiragame(statement, indices: indices))
  }
  return records
}

/**
 * A structure representing a SQLite database.
 * 
 * ### Database Schema
 * 
 * The schema captures the SQLite table/view catalog as safe Swift types.
 * 
 * #### Tables
 * 
 * - ``Game``      (SQL: `game`)
 * - ``Rom``       (SQL: `rom`)
 * - ``Serial``    (SQL: `serial`)
 * - ``Shiragame`` (SQL: `shiragame`)
 * 
 * > Hint: Use [SQL Views](https://www.sqlite.org/lang_createview.html)
 * >       to create Swift types that represent common queries.
 * >       (E.g. joins between tables or fragments of table data.)
 * 
 * ### Examples
 * 
 * Perform record operations on ``Game`` records:
 * ```swift
 * let records = try await db.games.filter(orderBy: \.platformId) {
 *   $0.platformId != nil
 * }
 * 
 * try await db.transaction { tx in
 *   var record = try tx.games.find(2) // find by primaryKey
 *   
 *   record.platformId = "Hunt"
 *   try tx.update(record)
 * 
 *   let newRecord = try tx.insert(record)
 *   try tx.delete(newRecord)
 * }
 * ```
 * 
 * Perform column selects on the `game` table:
 * ```swift
 * let values = try await db.select(from: \.games, \.platformId) {
 *   $0.in([ 2, 3 ])
 * }
 * ```
 * 
 * Perform low level operations on ``Game`` records:
 * ```swift
 * var db : OpaquePointer?
 * sqlite3_open_v2(path, &db, SQLITE_OPEN_READWRITE, nil)
 * 
 * var records = sqlite3_games_fetch(db, orderBy: "platformId", limit: 5) {
 *   $0.platformId != nil
 * }!
 * records[1].platformId = "Hunt"
 * sqlite3_games_update(db, records[1])
 * 
 * sqlite3_games_delete(db, records[0])
 * sqlite3_games_insert(db, records[0]) // re-add
 * ```
 */
@dynamicMemberLookup
public struct ShiragameSchema : SQLDatabase, SQLDatabaseAsyncChangeOperations, SQLCreationStatementsHolder {
  
  /**
   * Mappings of table/view Swift types to their "reference name".
   * 
   * The `RecordTypes` structure contains a variable for the Swift type
   * associated each table/view of the database. It maps the tables
   * "reference names" (e.g. ``games``) to the
   * "record type" of the table (e.g. ``Game``.self).
   */
  public struct RecordTypes : Swift.Sendable {
    
    /// Returns the Game type information (SQL: `game`).
    public let games = Game.self
    
    /// Returns the Rom type information (SQL: `rom`).
    public let roms = Rom.self
    
    /// Returns the Serial type information (SQL: `serial`).
    public let serials = Serial.self
    
    /// Returns the Shiragame type information (SQL: `shiragame`).
    public let shiragames = Shiragame.self
  }
  
  /// Property based access to the ``RecordTypes-swift.struct``.
  public static let recordTypes = RecordTypes()
  
  #if swift(>=5.7)
  /// All RecordTypes defined in the database.
  public static let _allRecordTypes : [ any SQLRecord.Type ] = [ Game.self, Rom.self, Serial.self, Shiragame.self ]
  #endif // swift(>=5.7)
  
  /// User version of the database (`PRAGMA user_version`).
  public static let userVersion = 0
  
  /// Whether `INSERT … RETURNING` should be used (requires SQLite 3.35.0+).
  public static let useInsertReturning = sqlite3_libversion_number() >= 3035000
  
  /// SQL that can be used to recreate the database structure.
  @inlinable
  public static var creationSQL : String {
    var sql = ""
    sql.append(Game.Schema.create)
    sql.append(Rom.Schema.create)
    sql.append(Serial.Schema.create)
    sql.append(Shiragame.Schema.create)
    return sql
  }
  
  public static func withOptCString<R>(
    _ s: String?,
    _ body: ( UnsafePointer<CChar>? ) throws -> R
  ) rethrows -> R
  {
    if let s = s { return try s.withCString(body) }
    else { return try body(nil) }
  }
  
  /// The `connectionHandler` is used to open SQLite database connections.
  public var connectionHandler : SQLConnectionHandler
  
  /**
   * Initialize ``ShiragameSchema`` with a `URL`.
   * 
   * Configures the database with a simple connection pool opening the
   * specified `URL`.
   * And optional `readOnly` flag can be set (defaults to `false`).
   * 
   * Example:
   * ```swift
   * let db = ShiragameSchema(url: ...)
   * 
   * // Write operations will raise an error.
   * let readOnly = ShiragameSchema(
   *   url: Bundle.module.url(forResource: "samples", withExtension: "db"),
   *   readOnly: true
   * )
   * ```
   * 
   * - Parameters:
   *   - url: A `URL` pointing to the database to be used.
   *   - readOnly: Whether the database should be opened readonly (default: `false`).
   */
  @inlinable
  public init(url: URL, readOnly: Bool = false)
  {
    self.connectionHandler = .simplePool(url: url, readOnly: readOnly)
  }
  
  /**
   * Initialize ``ShiragameSchema`` w/ a `SQLConnectionHandler`.
   * 
   * `SQLConnectionHandler`'s are used to open SQLite database connections when
   * queries are run using the `Lighter` APIs.
   * The `SQLConnectionHandler` is a protocol and custom handlers
   * can be provided.
   * 
   * Example:
   * ```swift
   * let db = ShiragameSchema(connectionHandler: .simplePool(
   *   url: Bundle.module.url(forResource: "samples", withExtension: "db"),
   *   readOnly: true,
   *   maxAge: 10,
   *   maximumPoolSizePerConfiguration: 4
   * ))
   * ```
   * 
   * - Parameters:
   *   - connectionHandler: The `SQLConnectionHandler` to use w/ the database.
   */
  @inlinable
  public init(connectionHandler: SQLConnectionHandler)
  {
    self.connectionHandler = connectionHandler
  }
}

/**
 * Record representing the `game` SQL table.
 * 
 * Record types represent rows within tables&views in a SQLite database.
 * They are returned by the functions or queries/filters generated by
 * Enlighter.
 * 
 * ### Examples
 * 
 * Perform record operations on ``Game`` records:
 * ```swift
 * let records = try await db.games.filter(orderBy: \.platformId) {
 *   $0.platformId != nil
 * }
 * 
 * try await db.transaction { tx in
 *   var record = try tx.games.find(2) // find by primaryKey
 *   
 *   record.platformId = "Hunt"
 *   try tx.update(record)
 * 
 *   let newRecord = try tx.insert(record)
 *   try tx.delete(newRecord)
 * }
 * ```
 * 
 * Perform column selects on the `game` table:
 * ```swift
 * let values = try await db.select(from: \.games, \.platformId) {
 *   $0.in([ 2, 3 ])
 * }
 * ```
 * 
 * Perform low level operations on ``Game`` records:
 * ```swift
 * var db : OpaquePointer?
 * sqlite3_open_v2(path, &db, SQLITE_OPEN_READWRITE, nil)
 * 
 * var records = sqlite3_games_fetch(db, orderBy: "platformId", limit: 5) {
 *   $0.platformId != nil
 * }!
 * records[1].platformId = "Hunt"
 * sqlite3_games_update(db, records[1])
 * 
 * sqlite3_games_delete(db, records[0])
 * sqlite3_games_insert(db, records[0]) // re-add
 * ```
 * 
 * ### SQL
 * 
 * The SQL used to create the table associated with the record:
 * ```sql
 * CREATE TABLE game ( 
 *         game_id INTEGER PRIMARY KEY,
 *         platform_id TEXT NOT NULL,
 *         entry_name TEXT NOT NULL,
 *         entry_title TEXT,
 *         release_title TEXT,
 *         region TEXT NOT NULL,
 *         part_number INTEGER,
 *         is_unlicensed BOOLEAN NOT NULL,
 *         is_demo BOOLEAN NOT NULL,
 *         is_system BOOLEAN NOT NULL,
 *         version TEXT,
 *         status TEXT,
 *         naming_convention TEXT,
 *         source TEXT NOT NULL
 *     )
 * ```
 */
public struct Game : Identifiable, SQLKeyedTableRecord, Codable, Sendable {
  
  /// Static SQL type information for the ``Game`` record.
  public static let schema = Schema()
  
  /// Primary key `game_id` (`INTEGER`), optional (default: `nil`).
  public var id : Int?
  
  /// Column `platform_id` (`TEXT`), required.
  public var platformId : String
  
  /// Column `entry_name` (`TEXT`), required.
  public var entryName : String
  
  /// Column `entry_title` (`TEXT`), optional (default: `nil`).
  public var entryTitle : String?
  
  /// Column `release_title` (`TEXT`), optional (default: `nil`).
  public var releaseTitle : String?
  
  /// Column `region` (`TEXT`), required.
  public var region : String
  
  /// Column `part_number` (`INTEGER`), optional (default: `nil`).
  public var partNumber : Int?
  
  /// Column `is_unlicensed` (`BOOLEAN`), required.
  public var isUnlicensed : Bool
  
  /// Column `is_demo` (`BOOLEAN`), required.
  public var isDemo : Bool
  
  /// Column `is_system` (`BOOLEAN`), required.
  public var isSystem : Bool
  
  /// Column `version` (`TEXT`), optional (default: `nil`).
  public var version : String?
  
  /// Column `status` (`TEXT`), optional (default: `nil`).
  public var status : String?
  
  /// Column `naming_convention` (`TEXT`), optional (default: `nil`).
  public var namingConvention : String?
  
  /// Column `source` (`TEXT`), required.
  public var source : String
  
  /**
   * Initialize a new ``Game`` record.
   * 
   * - Parameters:
   *   - id: Primary key `game_id` (`INTEGER`), optional (default: `nil`).
   *   - platformId: Column `platform_id` (`TEXT`), required.
   *   - entryName: Column `entry_name` (`TEXT`), required.
   *   - entryTitle: Column `entry_title` (`TEXT`), optional (default: `nil`).
   *   - releaseTitle: Column `release_title` (`TEXT`), optional (default: `nil`).
   *   - region: Column `region` (`TEXT`), required.
   *   - partNumber: Column `part_number` (`INTEGER`), optional (default: `nil`).
   *   - isUnlicensed: Column `is_unlicensed` (`BOOLEAN`), required.
   *   - isDemo: Column `is_demo` (`BOOLEAN`), required.
   *   - isSystem: Column `is_system` (`BOOLEAN`), required.
   *   - version: Column `version` (`TEXT`), optional (default: `nil`).
   *   - status: Column `status` (`TEXT`), optional (default: `nil`).
   *   - namingConvention: Column `naming_convention` (`TEXT`), optional (default: `nil`).
   *   - source: Column `source` (`TEXT`), required.
   */
  @inlinable
  public init(
    id: Int? = nil,
    platformId: String,
    entryName: String,
    entryTitle: String? = nil,
    releaseTitle: String? = nil,
    region: String,
    partNumber: Int? = nil,
    isUnlicensed: Bool,
    isDemo: Bool,
    isSystem: Bool,
    version: String? = nil,
    status: String? = nil,
    namingConvention: String? = nil,
    source: String
  )
  {
    self.id = id
    self.platformId = platformId
    self.entryName = entryName
    self.entryTitle = entryTitle
    self.releaseTitle = releaseTitle
    self.region = region
    self.partNumber = partNumber
    self.isUnlicensed = isUnlicensed
    self.isDemo = isDemo
    self.isSystem = isSystem
    self.version = version
    self.status = status
    self.namingConvention = namingConvention
    self.source = source
  }
}

/**
 * Record representing the `rom` SQL table.
 * 
 * Record types represent rows within tables&views in a SQLite database.
 * They are returned by the functions or queries/filters generated by
 * Enlighter.
 * 
 * ### Examples
 * 
 * Perform record operations on ``Rom`` records:
 * ```swift
 * let records = try await db.roms.filter(orderBy: \.fileName) {
 *   $0.fileName != nil
 * }
 * 
 * try await db.transaction { tx in
 *   var record = try tx.roms.find(2) // find by primaryKey
 *   
 *   record.fileName = "Hunt"
 *   try tx.update(record)
 * 
 *   let newRecord = try tx.insert(record)
 *   try tx.delete(newRecord)
 * }
 * ```
 * 
 * Perform column selects on the `rom` table:
 * ```swift
 * let values = try await db.select(from: \.roms, \.fileName) {
 *   $0.in([ 2, 3 ])
 * }
 * ```
 * 
 * Perform low level operations on ``Rom`` records:
 * ```swift
 * var db : OpaquePointer?
 * sqlite3_open_v2(path, &db, SQLITE_OPEN_READWRITE, nil)
 * 
 * var records = sqlite3_roms_fetch(db, orderBy: "fileName", limit: 5) {
 *   $0.fileName != nil
 * }!
 * records[1].fileName = "Hunt"
 * sqlite3_roms_update(db, records[1])
 * 
 * sqlite3_roms_delete(db, records[0])
 * sqlite3_roms_insert(db, records[0]) // re-add
 * ```
 * 
 * ### SQL
 * 
 * The SQL used to create the table associated with the record:
 * ```sql
 * CREATE TABLE rom ( 
 *         file_name TEXT NOT NULL,
 *         mimetype TEXT,
 *         md5 TEXT,
 *         crc TEXT,
 *         sha1 TEXT,
 *         size INTEGER NOT NULL,
 *         game_id INTEGER NOT NULL,
 *         FOREIGN KEY (game_id) REFERENCES game (game_id)
 *     )
 * ```
 */
public struct Rom : SQLTableRecord, Codable, Sendable {
  
  /// Static SQL type information for the ``Rom`` record.
  public static let schema = Schema()
  
  /// Column `file_name` (`TEXT`), required.
  public var fileName : String
  
  /// Column `mimetype` (`TEXT`), optional (default: `nil`).
  public var mimetype : String?
  
  /// Column `md5` (`TEXT`), optional (default: `nil`).
  public var md5 : String?
  
  /// Column `crc` (`TEXT`), optional (default: `nil`).
  public var crc : String?
  
  /// Column `sha1` (`TEXT`), optional (default: `nil`).
  public var sha1 : String?
  
  /// Column `size` (`INTEGER`), required.
  public var size : Int
  
  /// Column `game_id` (`INTEGER`), required.
  public var gameId : Int
  
  /**
   * Initialize a new ``Rom`` record.
   * 
   * - Parameters:
   *   - fileName: Column `file_name` (`TEXT`), required.
   *   - mimetype: Column `mimetype` (`TEXT`), optional (default: `nil`).
   *   - md5: Column `md5` (`TEXT`), optional (default: `nil`).
   *   - crc: Column `crc` (`TEXT`), optional (default: `nil`).
   *   - sha1: Column `sha1` (`TEXT`), optional (default: `nil`).
   *   - size: Column `size` (`INTEGER`), required.
   *   - gameId: Column `game_id` (`INTEGER`), required.
   */
  @inlinable
  public init(
    fileName: String,
    mimetype: String? = nil,
    md5: String? = nil,
    crc: String? = nil,
    sha1: String? = nil,
    size: Int,
    gameId: Int
  )
  {
    self.fileName = fileName
    self.mimetype = mimetype
    self.md5 = md5
    self.crc = crc
    self.sha1 = sha1
    self.size = size
    self.gameId = gameId
  }
}

/**
 * Record representing the `serial` SQL table.
 * 
 * Record types represent rows within tables&views in a SQLite database.
 * They are returned by the functions or queries/filters generated by
 * Enlighter.
 * 
 * ### Examples
 * 
 * Perform record operations on ``Serial`` records:
 * ```swift
 * let records = try await db.serials.filter(orderBy: \.serial) {
 *   $0.serial != nil
 * }
 * 
 * try await db.transaction { tx in
 *   var record = try tx.serials.find(2) // find by primaryKey
 *   
 *   record.serial = "Hunt"
 *   try tx.update(record)
 * 
 *   let newRecord = try tx.insert(record)
 *   try tx.delete(newRecord)
 * }
 * ```
 * 
 * Perform column selects on the `serial` table:
 * ```swift
 * let values = try await db.select(from: \.serials, \.serial) {
 *   $0.in([ 2, 3 ])
 * }
 * ```
 * 
 * Perform low level operations on ``Serial`` records:
 * ```swift
 * var db : OpaquePointer?
 * sqlite3_open_v2(path, &db, SQLITE_OPEN_READWRITE, nil)
 * 
 * var records = sqlite3_serials_fetch(db, orderBy: "serial", limit: 5) {
 *   $0.serial != nil
 * }!
 * records[1].serial = "Hunt"
 * sqlite3_serials_update(db, records[1])
 * 
 * sqlite3_serials_delete(db, records[0])
 * sqlite3_serials_insert(db, records[0]) // re-add
 * ```
 * 
 * ### SQL
 * 
 * The SQL used to create the table associated with the record:
 * ```sql
 * CREATE TABLE serial ( 
 *         serial TEXT NOT NULL,
 *         normalized TEXT NOT NULL,
 *         game_id INTEGER NOT NULL,
 *         FOREIGN KEY (game_id) REFERENCES game (game_id)
 *     )
 * ```
 */
public struct Serial : SQLTableRecord, Codable, Sendable {
  
  /// Static SQL type information for the ``Serial`` record.
  public static let schema = Schema()
  
  /// Column `serial` (`TEXT`), required.
  public var serial : String
  
  /// Column `normalized` (`TEXT`), required.
  public var normalized : String
  
  /// Column `game_id` (`INTEGER`), required.
  public var gameId : Int
  
  /**
   * Initialize a new ``Serial`` record.
   * 
   * - Parameters:
   *   - serial: Column `serial` (`TEXT`), required.
   *   - normalized: Column `normalized` (`TEXT`), required.
   *   - gameId: Column `game_id` (`INTEGER`), required.
   */
  @inlinable
  public init(serial: String, normalized: String, gameId: Int)
  {
    self.serial = serial
    self.normalized = normalized
    self.gameId = gameId
  }
}

/**
 * Record representing the `shiragame` SQL table.
 * 
 * Record types represent rows within tables&views in a SQLite database.
 * They are returned by the functions or queries/filters generated by
 * Enlighter.
 * 
 * ### Examples
 * 
 * Perform record operations on ``Shiragame`` records:
 * ```swift
 * let records = try await db.shiragames.filter(orderBy: \.shiragame) {
 *   $0.shiragame != nil
 * }
 * 
 * try await db.transaction { tx in
 *   var record = try tx.shiragames.find(2) // find by primaryKey
 *   
 *   record.shiragame = "Hunt"
 *   try tx.update(record)
 * 
 *   let newRecord = try tx.insert(record)
 *   try tx.delete(newRecord)
 * }
 * ```
 * 
 * Perform column selects on the `shiragame` table:
 * ```swift
 * let values = try await db.select(from: \.shiragames, \.shiragame) {
 *   $0.in([ 2, 3 ])
 * }
 * ```
 * 
 * Perform low level operations on ``Shiragame`` records:
 * ```swift
 * var db : OpaquePointer?
 * sqlite3_open_v2(path, &db, SQLITE_OPEN_READWRITE, nil)
 * 
 * var records = sqlite3_shiragames_fetch(db, orderBy: "shiragame", limit: 5) {
 *   $0.shiragame != nil
 * }!
 * records[1].shiragame = "Hunt"
 * sqlite3_shiragames_update(db, records[1])
 * 
 * sqlite3_shiragames_delete(db, records[0])
 * sqlite3_shiragames_insert(db, records[0]) // re-add
 * ```
 * 
 * ### SQL
 * 
 * The SQL used to create the table associated with the record:
 * ```sql
 * CREATE TABLE shiragame (
 *         shiragame TEXT,
 *         schema_version TEXT,
 *         stone_version TEXT,
 *         generated TEXT,
 *         release TEXT,
 *         aggregator TEXT
 *     )
 * ```
 */
public struct Shiragame : SQLTableRecord, Codable, Sendable {
  
  /// Static SQL type information for the ``Shiragame`` record.
  public static let schema = Schema()
  
  /// Column `shiragame` (`TEXT`), optional (default: `nil`).
  public var shiragame : String?
  
  /// Column `schema_version` (`TEXT`), optional (default: `nil`).
  public var schemaVersion : String?
  
  /// Column `stone_version` (`TEXT`), optional (default: `nil`).
  public var stoneVersion : String?
  
  /// Column `generated` (`TEXT`), optional (default: `nil`).
  public var generated : String?
  
  /// Column `release` (`TEXT`), optional (default: `nil`).
  public var release : String?
  
  /// Column `aggregator` (`TEXT`), optional (default: `nil`).
  public var aggregator : String?
  
  /**
   * Initialize a new ``Shiragame`` record.
   * 
   * - Parameters:
   *   - shiragame: Column `shiragame` (`TEXT`), optional (default: `nil`).
   *   - schemaVersion: Column `schema_version` (`TEXT`), optional (default: `nil`).
   *   - stoneVersion: Column `stone_version` (`TEXT`), optional (default: `nil`).
   *   - generated: Column `generated` (`TEXT`), optional (default: `nil`).
   *   - release: Column `release` (`TEXT`), optional (default: `nil`).
   *   - aggregator: Column `aggregator` (`TEXT`), optional (default: `nil`).
   */
  @inlinable
  public init(
    shiragame: String? = nil,
    schemaVersion: String? = nil,
    stoneVersion: String? = nil,
    generated: String? = nil,
    release: String? = nil,
    aggregator: String? = nil
  )
  {
    self.shiragame = shiragame
    self.schemaVersion = schemaVersion
    self.stoneVersion = stoneVersion
    self.generated = generated
    self.release = release
    self.aggregator = aggregator
  }
}

public extension Game {
  
  /**
   * Static type information for the ``Game`` record (`game` SQL table).
   * 
   * This structure captures the static SQL information associated with the
   * record.
   * It is used for static type lookups and more.
   */
  struct Schema : SQLKeyedTableSchema, SQLSwiftMatchableSchema, SQLCreatableSchema {
    
    public typealias PropertyIndices = ( idx_id: Int32, idx_platformId: Int32, idx_entryName: Int32, idx_entryTitle: Int32, idx_releaseTitle: Int32, idx_region: Int32, idx_partNumber: Int32, idx_isUnlicensed: Int32, idx_isDemo: Int32, idx_isSystem: Int32, idx_version: Int32, idx_status: Int32, idx_namingConvention: Int32, idx_source: Int32 )
    public typealias RecordType = Game
    public typealias MatchClosureType = ( Game ) -> Bool
    
    /// The SQL table name associated with the ``Game`` record.
    public static let externalName = "game"
    
    /// The number of columns the `game` table has.
    public static let columnCount : Int32 = 14
    
    /// Information on the records primary key (``Game/id``).
    public static let primaryKeyColumn = MappedColumn<Game, Int?>(
      externalName: "game_id",
      defaultValue: nil,
      keyPath: \Game.id
    )
    
    /// The SQL used to create the `game` table.
    public static let create = 
      #"""
      CREATE TABLE game ( 
              game_id INTEGER PRIMARY KEY,
              platform_id TEXT NOT NULL,
              entry_name TEXT NOT NULL,
              entry_title TEXT,
              release_title TEXT,
              region TEXT NOT NULL,
              part_number INTEGER,
              is_unlicensed BOOLEAN NOT NULL,
              is_demo BOOLEAN NOT NULL,
              is_system BOOLEAN NOT NULL,
              version TEXT,
              status TEXT,
              naming_convention TEXT,
              source TEXT NOT NULL
          );
      """#
    
    /// SQL to `SELECT` all columns of the `game` table.
    public static let select = #"SELECT "game_id", "platform_id", "entry_name", "entry_title", "release_title", "region", "part_number", "is_unlicensed", "is_demo", "is_system", "version", "status", "naming_convention", "source" FROM "game""#
    
    /// SQL fragment representing all columns.
    public static let selectColumns = #""game_id", "platform_id", "entry_name", "entry_title", "release_title", "region", "part_number", "is_unlicensed", "is_demo", "is_system", "version", "status", "naming_convention", "source""#
    
    /// Index positions of the properties in ``selectColumns``.
    public static let selectColumnIndices : PropertyIndices = ( 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13 )
    
    /// SQL to `SELECT` all columns of the `game` table using a Swift filter.
    public static let matchSelect = #"SELECT "game_id", "platform_id", "entry_name", "entry_title", "release_title", "region", "part_number", "is_unlicensed", "is_demo", "is_system", "version", "status", "naming_convention", "source" FROM "game" WHERE games_swift_match("game_id", "platform_id", "entry_name", "entry_title", "release_title", "region", "part_number", "is_unlicensed", "is_demo", "is_system", "version", "status", "naming_convention", "source") != 0"#
    
    /// SQL to `UPDATE` all columns of the `game` table.
    public static let update = #"UPDATE "game" SET "platform_id" = ?, "entry_name" = ?, "entry_title" = ?, "release_title" = ?, "region" = ?, "part_number" = ?, "is_unlicensed" = ?, "is_demo" = ?, "is_system" = ?, "version" = ?, "status" = ?, "naming_convention" = ?, "source" = ? WHERE "game_id" = ?"#
    
    /// Property parameter indicies in the ``update`` SQL
    public static let updateParameterIndices : PropertyIndices = ( 14, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13 )
    
    /// SQL to `INSERT` a record into the `game` table.
    public static let insert = #"INSERT INTO "game" ( "platform_id", "entry_name", "entry_title", "release_title", "region", "part_number", "is_unlicensed", "is_demo", "is_system", "version", "status", "naming_convention", "source" ) VALUES ( ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ? )"#
    
    /// SQL to `INSERT` a record into the `game` table.
    public static let insertReturning = #"INSERT INTO "game" ( "platform_id", "entry_name", "entry_title", "release_title", "region", "part_number", "is_unlicensed", "is_demo", "is_system", "version", "status", "naming_convention", "source" ) VALUES ( ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ? ) RETURNING "game_id", "platform_id", "entry_name", "entry_title", "release_title", "region", "part_number", "is_unlicensed", "is_demo", "is_system", "version", "status", "naming_convention", "source""#
    
    /// Property parameter indicies in the ``insert`` SQL
    public static let insertParameterIndices : PropertyIndices = ( -1, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13 )
    
    /// SQL to `DELETE` a record from the `game` table.
    public static let delete = #"DELETE FROM "game" WHERE "game_id" = ?"#
    
    /// Property parameter indicies in the ``delete`` SQL
    public static let deleteParameterIndices : PropertyIndices = ( 1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 )
    
    /**
     * Lookup property indices by column name in a statement handle.
     * 
     * Properties are ordered in the schema and have a specific index
     * assigned.
     * E.g. if the record has two properties, `id` and `name`,
     * and the query was `SELECT age, game_id FROM game`,
     * this would return `( idx_id: 1, idx_name: -1 )`.
     * Because the `game_id` is in the second position and `name`
     * isn't provided at all.
     * 
     * - Parameters:
     *   - statement: A raw SQLite3 prepared statement handle.
     * - Returns: The positions of the properties in the prepared statement.
     */
    @inlinable
    public static func lookupColumnIndices(`in` statement: OpaquePointer!)
      -> PropertyIndices
    {
      var indices : PropertyIndices = ( -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 )
      for i in 0..<sqlite3_column_count(statement) {
        let col = sqlite3_column_name(statement, i)
        if strcmp(col!, "game_id") == 0 {
          indices.idx_id = i
        }
        else if strcmp(col!, "platform_id") == 0 {
          indices.idx_platformId = i
        }
        else if strcmp(col!, "entry_name") == 0 {
          indices.idx_entryName = i
        }
        else if strcmp(col!, "entry_title") == 0 {
          indices.idx_entryTitle = i
        }
        else if strcmp(col!, "release_title") == 0 {
          indices.idx_releaseTitle = i
        }
        else if strcmp(col!, "region") == 0 {
          indices.idx_region = i
        }
        else if strcmp(col!, "part_number") == 0 {
          indices.idx_partNumber = i
        }
        else if strcmp(col!, "is_unlicensed") == 0 {
          indices.idx_isUnlicensed = i
        }
        else if strcmp(col!, "is_demo") == 0 {
          indices.idx_isDemo = i
        }
        else if strcmp(col!, "is_system") == 0 {
          indices.idx_isSystem = i
        }
        else if strcmp(col!, "version") == 0 {
          indices.idx_version = i
        }
        else if strcmp(col!, "status") == 0 {
          indices.idx_status = i
        }
        else if strcmp(col!, "naming_convention") == 0 {
          indices.idx_namingConvention = i
        }
        else if strcmp(col!, "source") == 0 {
          indices.idx_source = i
        }
      }
      return indices
    }
    
    /**
     * Register the Swift matcher function for the ``Game`` record.
     * 
     * SQLite Swift matcher functions are used to process `filter` queries
     * and low-level matching w/o the Lighter library.
     * 
     * - Parameters:
     *   - unsafeDatabaseHandle: SQLite3 database handle.
     *   - flags: SQLite3 function registration flags, default: `SQLITE_UTF8`
     *   - matcher: A pointer to the Swift closure used to filter the records.
     * - Returns: The result code of `sqlite3_create_function`, e.g. `SQLITE_OK`.
     */
    @inlinable
    @discardableResult
    public static func registerSwiftMatcher(
      `in` unsafeDatabaseHandle: OpaquePointer!,
      flags: Int32 = SQLITE_UTF8,
      matcher: UnsafeRawPointer
    ) -> Int32
    {
      func dispatch(
        _ context: OpaquePointer?,
        argc: Int32,
        argv: UnsafeMutablePointer<OpaquePointer?>!
      )
      {
        if let closureRawPtr = sqlite3_user_data(context) {
          let closurePtr = closureRawPtr.bindMemory(to: MatchClosureType.self, capacity: 1)
          let indices = Game.Schema.selectColumnIndices
          let record = Game(
            id: (indices.idx_id >= 0) && (indices.idx_id < argc) ? (sqlite3_value_type(argv[Int(indices.idx_id)]) != SQLITE_NULL ? Int(sqlite3_value_int64(argv[Int(indices.idx_id)])) : nil) : RecordType.schema.id.defaultValue,
            platformId: ((indices.idx_platformId >= 0) && (indices.idx_platformId < argc) ? (sqlite3_value_text(argv[Int(indices.idx_platformId)]).flatMap(String.init(cString:))) : nil) ?? RecordType.schema.platformId.defaultValue,
            entryName: ((indices.idx_entryName >= 0) && (indices.idx_entryName < argc) ? (sqlite3_value_text(argv[Int(indices.idx_entryName)]).flatMap(String.init(cString:))) : nil) ?? RecordType.schema.entryName.defaultValue,
            entryTitle: (indices.idx_entryTitle >= 0) && (indices.idx_entryTitle < argc) ? (sqlite3_value_text(argv[Int(indices.idx_entryTitle)]).flatMap(String.init(cString:))) : RecordType.schema.entryTitle.defaultValue,
            releaseTitle: (indices.idx_releaseTitle >= 0) && (indices.idx_releaseTitle < argc) ? (sqlite3_value_text(argv[Int(indices.idx_releaseTitle)]).flatMap(String.init(cString:))) : RecordType.schema.releaseTitle.defaultValue,
            region: ((indices.idx_region >= 0) && (indices.idx_region < argc) ? (sqlite3_value_text(argv[Int(indices.idx_region)]).flatMap(String.init(cString:))) : nil) ?? RecordType.schema.region.defaultValue,
            partNumber: (indices.idx_partNumber >= 0) && (indices.idx_partNumber < argc) ? (sqlite3_value_type(argv[Int(indices.idx_partNumber)]) != SQLITE_NULL ? Int(sqlite3_value_int64(argv[Int(indices.idx_partNumber)])) : nil) : RecordType.schema.partNumber.defaultValue,
            isUnlicensed: (indices.idx_isUnlicensed >= 0) && (indices.idx_isUnlicensed < argc) && (sqlite3_value_type(argv[Int(indices.idx_isUnlicensed)]) != SQLITE_NULL) ? (sqlite3_value_int64(argv[Int(indices.idx_isUnlicensed)]) != 0) : RecordType.schema.isUnlicensed.defaultValue,
            isDemo: (indices.idx_isDemo >= 0) && (indices.idx_isDemo < argc) && (sqlite3_value_type(argv[Int(indices.idx_isDemo)]) != SQLITE_NULL) ? (sqlite3_value_int64(argv[Int(indices.idx_isDemo)]) != 0) : RecordType.schema.isDemo.defaultValue,
            isSystem: (indices.idx_isSystem >= 0) && (indices.idx_isSystem < argc) && (sqlite3_value_type(argv[Int(indices.idx_isSystem)]) != SQLITE_NULL) ? (sqlite3_value_int64(argv[Int(indices.idx_isSystem)]) != 0) : RecordType.schema.isSystem.defaultValue,
            version: (indices.idx_version >= 0) && (indices.idx_version < argc) ? (sqlite3_value_text(argv[Int(indices.idx_version)]).flatMap(String.init(cString:))) : RecordType.schema.version.defaultValue,
            status: (indices.idx_status >= 0) && (indices.idx_status < argc) ? (sqlite3_value_text(argv[Int(indices.idx_status)]).flatMap(String.init(cString:))) : RecordType.schema.status.defaultValue,
            namingConvention: (indices.idx_namingConvention >= 0) && (indices.idx_namingConvention < argc) ? (sqlite3_value_text(argv[Int(indices.idx_namingConvention)]).flatMap(String.init(cString:))) : RecordType.schema.namingConvention.defaultValue,
            source: ((indices.idx_source >= 0) && (indices.idx_source < argc) ? (sqlite3_value_text(argv[Int(indices.idx_source)]).flatMap(String.init(cString:))) : nil) ?? RecordType.schema.source.defaultValue
          )
          sqlite3_result_int(context, closurePtr.pointee(record) ? 1 : 0)
        }
        else {
          sqlite3_result_error(context, "Missing Swift matcher closure", -1)
        }
      }
      return sqlite3_create_function(
        unsafeDatabaseHandle,
        "games_swift_match",
        Game.Schema.columnCount,
        flags,
        UnsafeMutableRawPointer(mutating: matcher),
        dispatch,
        nil,
        nil
      )
    }
    
    /**
     * Unregister the Swift matcher function for the ``Game`` record.
     * 
     * SQLite Swift matcher functions are used to process `filter` queries
     * and low-level matching w/o the Lighter library.
     * 
     * - Parameters:
     *   - unsafeDatabaseHandle: SQLite3 database handle.
     *   - flags: SQLite3 function registration flags, default: `SQLITE_UTF8`
     * - Returns: The result code of `sqlite3_create_function`, e.g. `SQLITE_OK`.
     */
    @inlinable
    @discardableResult
    public static func unregisterSwiftMatcher(
      `in` unsafeDatabaseHandle: OpaquePointer!,
      flags: Int32 = SQLITE_UTF8
    ) -> Int32
    {
      sqlite3_create_function(
        unsafeDatabaseHandle,
        "games_swift_match",
        Game.Schema.columnCount,
        flags,
        nil,
        nil,
        nil,
        nil
      )
    }
    
    /// Type information for property ``Game/id`` (`game_id` column).
    public let id = MappedColumn<Game, Int?>(
      externalName: "game_id",
      defaultValue: nil,
      keyPath: \Game.id
    )
    
    /// Type information for property ``Game/platformId`` (`platform_id` column).
    public let platformId = MappedColumn<Game, String>(
      externalName: "platform_id",
      defaultValue: "",
      keyPath: \Game.platformId
    )
    
    /// Type information for property ``Game/entryName`` (`entry_name` column).
    public let entryName = MappedColumn<Game, String>(
      externalName: "entry_name",
      defaultValue: "",
      keyPath: \Game.entryName
    )
    
    /// Type information for property ``Game/entryTitle`` (`entry_title` column).
    public let entryTitle = MappedColumn<Game, String?>(
      externalName: "entry_title",
      defaultValue: nil,
      keyPath: \Game.entryTitle
    )
    
    /// Type information for property ``Game/releaseTitle`` (`release_title` column).
    public let releaseTitle = MappedColumn<Game, String?>(
      externalName: "release_title",
      defaultValue: nil,
      keyPath: \Game.releaseTitle
    )
    
    /// Type information for property ``Game/region`` (`region` column).
    public let region = MappedColumn<Game, String>(
      externalName: "region",
      defaultValue: "",
      keyPath: \Game.region
    )
    
    /// Type information for property ``Game/partNumber`` (`part_number` column).
    public let partNumber = MappedColumn<Game, Int?>(
      externalName: "part_number",
      defaultValue: nil,
      keyPath: \Game.partNumber
    )
    
    /// Type information for property ``Game/isUnlicensed`` (`is_unlicensed` column).
    public let isUnlicensed = MappedColumn<Game, Bool>(
      externalName: "is_unlicensed",
      defaultValue: false,
      keyPath: \Game.isUnlicensed
    )
    
    /// Type information for property ``Game/isDemo`` (`is_demo` column).
    public let isDemo = MappedColumn<Game, Bool>(
      externalName: "is_demo",
      defaultValue: false,
      keyPath: \Game.isDemo
    )
    
    /// Type information for property ``Game/isSystem`` (`is_system` column).
    public let isSystem = MappedColumn<Game, Bool>(
      externalName: "is_system",
      defaultValue: false,
      keyPath: \Game.isSystem
    )
    
    /// Type information for property ``Game/version`` (`version` column).
    public let version = MappedColumn<Game, String?>(
      externalName: "version",
      defaultValue: nil,
      keyPath: \Game.version
    )
    
    /// Type information for property ``Game/status`` (`status` column).
    public let status = MappedColumn<Game, String?>(
      externalName: "status",
      defaultValue: nil,
      keyPath: \Game.status
    )
    
    /// Type information for property ``Game/namingConvention`` (`naming_convention` column).
    public let namingConvention = MappedColumn<Game, String?>(
      externalName: "naming_convention",
      defaultValue: nil,
      keyPath: \Game.namingConvention
    )
    
    /// Type information for property ``Game/source`` (`source` column).
    public let source = MappedColumn<Game, String>(
      externalName: "source",
      defaultValue: "",
      keyPath: \Game.source
    )
    
    #if swift(>=5.7)
    public var _allColumns : [ any SQLColumn ] { [ id, platformId, entryName, entryTitle, releaseTitle, region, partNumber, isUnlicensed, isDemo, isSystem, version, status, namingConvention, source ] }
    #endif // swift(>=5.7)
    
    public init()
    {
    }
  }
  
  /**
   * Initialize a ``Game`` record from a SQLite statement handle.
   * 
   * This initializer allows easy setup of a record structure from an
   * otherwise arbitrarily constructed SQLite prepared statement.
   * 
   * If no `indices` are specified, the `Schema/lookupColumnIndices`
   * function will be used to find the positions of the structure properties
   * based on their external name.
   * When looping, it is recommended to do the lookup once, and then
   * provide the `indices` to the initializer.
   * 
   * Required values that are missing in the statement are replaced with
   * their assigned default values, i.e. this can even be used to perform
   * partial selects w/ only a minor overhead (the extra space for a
   * record).
   * 
   * Example:
   * ```swift
   * var statement : OpaquePointer?
   * sqlite3_prepare_v2(dbHandle, "SELECT * FROM game", -1, &statement, nil)
   * while sqlite3_step(statement) == SQLITE_ROW {
   *   let record = Game(statement)
   *   print("Fetched:", record)
   * }
   * sqlite3_finalize(statement)
   * ```
   * 
   * - Parameters:
   *   - statement: Statement handle as returned by `sqlite3_prepare*` functions.
   *   - indices: Property bindings positions, defaults to `nil` (automatic lookup).
   */
  @inlinable
  init(_ statement: OpaquePointer!, indices: Schema.PropertyIndices? = nil)
  {
    let indices = indices ?? Self.Schema.lookupColumnIndices(in: statement)
    let argc = sqlite3_column_count(statement)
    self.init(
      id: (indices.idx_id >= 0) && (indices.idx_id < argc) ? (sqlite3_column_type(statement, indices.idx_id) != SQLITE_NULL ? Int(sqlite3_column_int64(statement, indices.idx_id)) : nil) : Self.schema.id.defaultValue,
      platformId: ((indices.idx_platformId >= 0) && (indices.idx_platformId < argc) ? (sqlite3_column_text(statement, indices.idx_platformId).flatMap(String.init(cString:))) : nil) ?? Self.schema.platformId.defaultValue,
      entryName: ((indices.idx_entryName >= 0) && (indices.idx_entryName < argc) ? (sqlite3_column_text(statement, indices.idx_entryName).flatMap(String.init(cString:))) : nil) ?? Self.schema.entryName.defaultValue,
      entryTitle: (indices.idx_entryTitle >= 0) && (indices.idx_entryTitle < argc) ? (sqlite3_column_text(statement, indices.idx_entryTitle).flatMap(String.init(cString:))) : Self.schema.entryTitle.defaultValue,
      releaseTitle: (indices.idx_releaseTitle >= 0) && (indices.idx_releaseTitle < argc) ? (sqlite3_column_text(statement, indices.idx_releaseTitle).flatMap(String.init(cString:))) : Self.schema.releaseTitle.defaultValue,
      region: ((indices.idx_region >= 0) && (indices.idx_region < argc) ? (sqlite3_column_text(statement, indices.idx_region).flatMap(String.init(cString:))) : nil) ?? Self.schema.region.defaultValue,
      partNumber: (indices.idx_partNumber >= 0) && (indices.idx_partNumber < argc) ? (sqlite3_column_type(statement, indices.idx_partNumber) != SQLITE_NULL ? Int(sqlite3_column_int64(statement, indices.idx_partNumber)) : nil) : Self.schema.partNumber.defaultValue,
      isUnlicensed: (indices.idx_isUnlicensed >= 0) && (indices.idx_isUnlicensed < argc) && (sqlite3_column_type(statement, indices.idx_isUnlicensed) != SQLITE_NULL) ? (sqlite3_column_int64(statement, indices.idx_isUnlicensed) != 0) : Self.schema.isUnlicensed.defaultValue,
      isDemo: (indices.idx_isDemo >= 0) && (indices.idx_isDemo < argc) && (sqlite3_column_type(statement, indices.idx_isDemo) != SQLITE_NULL) ? (sqlite3_column_int64(statement, indices.idx_isDemo) != 0) : Self.schema.isDemo.defaultValue,
      isSystem: (indices.idx_isSystem >= 0) && (indices.idx_isSystem < argc) && (sqlite3_column_type(statement, indices.idx_isSystem) != SQLITE_NULL) ? (sqlite3_column_int64(statement, indices.idx_isSystem) != 0) : Self.schema.isSystem.defaultValue,
      version: (indices.idx_version >= 0) && (indices.idx_version < argc) ? (sqlite3_column_text(statement, indices.idx_version).flatMap(String.init(cString:))) : Self.schema.version.defaultValue,
      status: (indices.idx_status >= 0) && (indices.idx_status < argc) ? (sqlite3_column_text(statement, indices.idx_status).flatMap(String.init(cString:))) : Self.schema.status.defaultValue,
      namingConvention: (indices.idx_namingConvention >= 0) && (indices.idx_namingConvention < argc) ? (sqlite3_column_text(statement, indices.idx_namingConvention).flatMap(String.init(cString:))) : Self.schema.namingConvention.defaultValue,
      source: ((indices.idx_source >= 0) && (indices.idx_source < argc) ? (sqlite3_column_text(statement, indices.idx_source).flatMap(String.init(cString:))) : nil) ?? Self.schema.source.defaultValue
    )
  }
  
  /**
   * Bind all ``Game`` properties to a prepared statement and call a closure.
   * 
   * *Important*: The bindings are only valid within the closure being executed!
   * 
   * Example:
   * ```swift
   * var statement : OpaquePointer?
   * sqlite3_prepare_v2(
   *   dbHandle,
   *   #"UPDATE "game" SET "platform_id" = ?, "entry_name" = ?, "entry_title" = ?, "release_title" = ?, "region" = ?, "part_number" = ?, "is_unlicensed" = ?, "is_demo" = ?, "is_system" = ?, "version" = ?, "status" = ?, "naming_convention" = ?, "source" = ? WHERE "game_id" = ?"#,
   *   -1, &statement, nil
   * )
   * 
   * let record = Game(id: 1, platformId: "Hello", entryName: "World", entryTitle: "Duck", releaseTitle: "Donald", region: "Mickey", partNumber: 2, isUnlicensed: ..., isDemo: ..., isSystem: ..., source: "string")
   * let ok = record.bind(to: statement, indices: ( 14, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13 )) {
   *   sqlite3_step(statement) == SQLITE_DONE
   * }
   * sqlite3_finalize(statement)
   * ```
   * 
   * - Parameters:
   *   - statement: A SQLite3 statement handle as returned by the `sqlite3_prepare*` functions.
   *   - indices: The parameter positions for the bindings.
   *   - execute: Closure executed with bindings applied, bindings _only_ valid within the call!
   * - Returns: Returns the result of the closure that is passed in.
   */
  @inlinable
  @discardableResult
  func bind<R>(
    to statement: OpaquePointer!,
    indices: Schema.PropertyIndices,
    then execute: () throws -> R
  ) rethrows -> R
  {
    if indices.idx_id >= 0 {
      if let id = id {
        sqlite3_bind_int64(statement, indices.idx_id, Int64(id))
      }
      else {
        sqlite3_bind_null(statement, indices.idx_id)
      }
    }
    return try platformId.withCString() { ( s ) in
      if indices.idx_platformId >= 0 {
        sqlite3_bind_text(statement, indices.idx_platformId, s, -1, nil)
      }
      return try entryName.withCString() { ( s ) in
        if indices.idx_entryName >= 0 {
          sqlite3_bind_text(statement, indices.idx_entryName, s, -1, nil)
        }
        return try ShiragameSchema.withOptCString(entryTitle) { ( s ) in
          if indices.idx_entryTitle >= 0 {
            sqlite3_bind_text(statement, indices.idx_entryTitle, s, -1, nil)
          }
          return try ShiragameSchema.withOptCString(releaseTitle) { ( s ) in
            if indices.idx_releaseTitle >= 0 {
              sqlite3_bind_text(statement, indices.idx_releaseTitle, s, -1, nil)
            }
            return try region.withCString() { ( s ) in
              if indices.idx_region >= 0 {
                sqlite3_bind_text(statement, indices.idx_region, s, -1, nil)
              }
              if indices.idx_partNumber >= 0 {
                if let partNumber = partNumber {
                  sqlite3_bind_int64(statement, indices.idx_partNumber, Int64(partNumber))
                }
                else {
                  sqlite3_bind_null(statement, indices.idx_partNumber)
                }
              }
              if indices.idx_isUnlicensed >= 0 {
                sqlite3_bind_int64(statement, indices.idx_isUnlicensed, isUnlicensed ? 1 : 0)
              }
              if indices.idx_isDemo >= 0 {
                sqlite3_bind_int64(statement, indices.idx_isDemo, isDemo ? 1 : 0)
              }
              if indices.idx_isSystem >= 0 {
                sqlite3_bind_int64(statement, indices.idx_isSystem, isSystem ? 1 : 0)
              }
              return try ShiragameSchema.withOptCString(version) { ( s ) in
                if indices.idx_version >= 0 {
                  sqlite3_bind_text(statement, indices.idx_version, s, -1, nil)
                }
                return try ShiragameSchema.withOptCString(status) { ( s ) in
                  if indices.idx_status >= 0 {
                    sqlite3_bind_text(statement, indices.idx_status, s, -1, nil)
                  }
                  return try ShiragameSchema.withOptCString(namingConvention) { ( s ) in
                    if indices.idx_namingConvention >= 0 {
                      sqlite3_bind_text(statement, indices.idx_namingConvention, s, -1, nil)
                    }
                    return try source.withCString() { ( s ) in
                      if indices.idx_source >= 0 {
                        sqlite3_bind_text(statement, indices.idx_source, s, -1, nil)
                      }
                      return try execute()
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}

public extension Rom {
  
  /**
   * Static type information for the ``Rom`` record (`rom` SQL table).
   * 
   * This structure captures the static SQL information associated with the
   * record.
   * It is used for static type lookups and more.
   */
  struct Schema : SQLTableSchema, SQLSwiftMatchableSchema, SQLCreatableSchema {
    
    public typealias PropertyIndices = ( idx_fileName: Int32, idx_mimetype: Int32, idx_md5: Int32, idx_crc: Int32, idx_sha1: Int32, idx_size: Int32, idx_gameId: Int32 )
    public typealias RecordType = Rom
    public typealias MatchClosureType = ( Rom ) -> Bool
    
    /// The SQL table name associated with the ``Rom`` record.
    public static let externalName = "rom"
    
    /// The number of columns the `rom` table has.
    public static let columnCount : Int32 = 7
    
    /// The SQL used to create the `rom` table.
    public static let create = 
      #"""
      CREATE TABLE rom ( 
              file_name TEXT NOT NULL,
              mimetype TEXT,
              md5 TEXT,
              crc TEXT,
              sha1 TEXT,
              size INTEGER NOT NULL,
              game_id INTEGER NOT NULL,
              FOREIGN KEY (game_id) REFERENCES game (game_id)
          );
      """#
    
    /// SQL to `SELECT` all columns of the `rom` table.
    public static let select = #"SELECT "file_name", "mimetype", "md5", "crc", "sha1", "size", "game_id" FROM "rom""#
    
    /// SQL fragment representing all columns.
    public static let selectColumns = #""file_name", "mimetype", "md5", "crc", "sha1", "size", "game_id""#
    
    /// Index positions of the properties in ``selectColumns``.
    public static let selectColumnIndices : PropertyIndices = ( 0, 1, 2, 3, 4, 5, 6 )
    
    /// SQL to `SELECT` all columns of the `rom` table using a Swift filter.
    public static let matchSelect = #"SELECT "file_name", "mimetype", "md5", "crc", "sha1", "size", "game_id" FROM "rom" WHERE roms_swift_match("file_name", "mimetype", "md5", "crc", "sha1", "size", "game_id") != 0"#
    
    /// SQL to `INSERT` a record into the `rom` table.
    public static let insert = #"INSERT INTO "rom" ( "file_name", "mimetype", "md5", "crc", "sha1", "size", "game_id" ) VALUES ( ?, ?, ?, ?, ?, ?, ? )"#
    
    /// SQL to `INSERT` a record into the `rom` table.
    public static let insertReturning = #"INSERT INTO "rom" ( "file_name", "mimetype", "md5", "crc", "sha1", "size", "game_id" ) VALUES ( ?, ?, ?, ?, ?, ?, ? ) RETURNING "file_name", "mimetype", "md5", "crc", "sha1", "size", "game_id""#
    
    /// Property parameter indicies in the ``insert`` SQL
    public static let insertParameterIndices : PropertyIndices = ( 1, 2, 3, 4, 5, 6, 7 )
    
    /// SQL to `DELETE` a record from the `rom` table.
    public static let delete = #"DELETE FROM "rom" WHERE "file_name" = ? AND "mimetype" = ? AND "md5" = ? AND "crc" = ? AND "sha1" = ? AND "size" = ? AND "game_id" = ?"#
    
    /// Property parameter indicies in the ``delete`` SQL
    public static let deleteParameterIndices : PropertyIndices = ( 1, 2, 3, 4, 5, 6, 7 )
    
    /**
     * Lookup property indices by column name in a statement handle.
     * 
     * Properties are ordered in the schema and have a specific index
     * assigned.
     * E.g. if the record has two properties, `id` and `name`,
     * and the query was `SELECT age, rom_id FROM rom`,
     * this would return `( idx_id: 1, idx_name: -1 )`.
     * Because the `rom_id` is in the second position and `name`
     * isn't provided at all.
     * 
     * - Parameters:
     *   - statement: A raw SQLite3 prepared statement handle.
     * - Returns: The positions of the properties in the prepared statement.
     */
    @inlinable
    public static func lookupColumnIndices(`in` statement: OpaquePointer!)
      -> PropertyIndices
    {
      var indices : PropertyIndices = ( -1, -1, -1, -1, -1, -1, -1 )
      for i in 0..<sqlite3_column_count(statement) {
        let col = sqlite3_column_name(statement, i)
        if strcmp(col!, "file_name") == 0 {
          indices.idx_fileName = i
        }
        else if strcmp(col!, "mimetype") == 0 {
          indices.idx_mimetype = i
        }
        else if strcmp(col!, "md5") == 0 {
          indices.idx_md5 = i
        }
        else if strcmp(col!, "crc") == 0 {
          indices.idx_crc = i
        }
        else if strcmp(col!, "sha1") == 0 {
          indices.idx_sha1 = i
        }
        else if strcmp(col!, "size") == 0 {
          indices.idx_size = i
        }
        else if strcmp(col!, "game_id") == 0 {
          indices.idx_gameId = i
        }
      }
      return indices
    }
    
    /**
     * Register the Swift matcher function for the ``Rom`` record.
     * 
     * SQLite Swift matcher functions are used to process `filter` queries
     * and low-level matching w/o the Lighter library.
     * 
     * - Parameters:
     *   - unsafeDatabaseHandle: SQLite3 database handle.
     *   - flags: SQLite3 function registration flags, default: `SQLITE_UTF8`
     *   - matcher: A pointer to the Swift closure used to filter the records.
     * - Returns: The result code of `sqlite3_create_function`, e.g. `SQLITE_OK`.
     */
    @inlinable
    @discardableResult
    public static func registerSwiftMatcher(
      `in` unsafeDatabaseHandle: OpaquePointer!,
      flags: Int32 = SQLITE_UTF8,
      matcher: UnsafeRawPointer
    ) -> Int32
    {
      func dispatch(
        _ context: OpaquePointer?,
        argc: Int32,
        argv: UnsafeMutablePointer<OpaquePointer?>!
      )
      {
        if let closureRawPtr = sqlite3_user_data(context) {
          let closurePtr = closureRawPtr.bindMemory(to: MatchClosureType.self, capacity: 1)
          let indices = Rom.Schema.selectColumnIndices
          let record = Rom(
            fileName: ((indices.idx_fileName >= 0) && (indices.idx_fileName < argc) ? (sqlite3_value_text(argv[Int(indices.idx_fileName)]).flatMap(String.init(cString:))) : nil) ?? RecordType.schema.fileName.defaultValue,
            mimetype: (indices.idx_mimetype >= 0) && (indices.idx_mimetype < argc) ? (sqlite3_value_text(argv[Int(indices.idx_mimetype)]).flatMap(String.init(cString:))) : RecordType.schema.mimetype.defaultValue,
            md5: (indices.idx_md5 >= 0) && (indices.idx_md5 < argc) ? (sqlite3_value_text(argv[Int(indices.idx_md5)]).flatMap(String.init(cString:))) : RecordType.schema.md5.defaultValue,
            crc: (indices.idx_crc >= 0) && (indices.idx_crc < argc) ? (sqlite3_value_text(argv[Int(indices.idx_crc)]).flatMap(String.init(cString:))) : RecordType.schema.crc.defaultValue,
            sha1: (indices.idx_sha1 >= 0) && (indices.idx_sha1 < argc) ? (sqlite3_value_text(argv[Int(indices.idx_sha1)]).flatMap(String.init(cString:))) : RecordType.schema.sha1.defaultValue,
            size: (indices.idx_size >= 0) && (indices.idx_size < argc) && (sqlite3_value_type(argv[Int(indices.idx_size)]) != SQLITE_NULL) ? Int(sqlite3_value_int64(argv[Int(indices.idx_size)])) : RecordType.schema.size.defaultValue,
            gameId: (indices.idx_gameId >= 0) && (indices.idx_gameId < argc) && (sqlite3_value_type(argv[Int(indices.idx_gameId)]) != SQLITE_NULL) ? Int(sqlite3_value_int64(argv[Int(indices.idx_gameId)])) : RecordType.schema.gameId.defaultValue
          )
          sqlite3_result_int(context, closurePtr.pointee(record) ? 1 : 0)
        }
        else {
          sqlite3_result_error(context, "Missing Swift matcher closure", -1)
        }
      }
      return sqlite3_create_function(
        unsafeDatabaseHandle,
        "roms_swift_match",
        Rom.Schema.columnCount,
        flags,
        UnsafeMutableRawPointer(mutating: matcher),
        dispatch,
        nil,
        nil
      )
    }
    
    /**
     * Unregister the Swift matcher function for the ``Rom`` record.
     * 
     * SQLite Swift matcher functions are used to process `filter` queries
     * and low-level matching w/o the Lighter library.
     * 
     * - Parameters:
     *   - unsafeDatabaseHandle: SQLite3 database handle.
     *   - flags: SQLite3 function registration flags, default: `SQLITE_UTF8`
     * - Returns: The result code of `sqlite3_create_function`, e.g. `SQLITE_OK`.
     */
    @inlinable
    @discardableResult
    public static func unregisterSwiftMatcher(
      `in` unsafeDatabaseHandle: OpaquePointer!,
      flags: Int32 = SQLITE_UTF8
    ) -> Int32
    {
      sqlite3_create_function(
        unsafeDatabaseHandle,
        "roms_swift_match",
        Rom.Schema.columnCount,
        flags,
        nil,
        nil,
        nil,
        nil
      )
    }
    
    /// Type information for property ``Rom/fileName`` (`file_name` column).
    public let fileName = MappedColumn<Rom, String>(
      externalName: "file_name",
      defaultValue: "",
      keyPath: \Rom.fileName
    )
    
    /// Type information for property ``Rom/mimetype`` (`mimetype` column).
    public let mimetype = MappedColumn<Rom, String?>(
      externalName: "mimetype",
      defaultValue: nil,
      keyPath: \Rom.mimetype
    )
    
    /// Type information for property ``Rom/md5`` (`md5` column).
    public let md5 = MappedColumn<Rom, String?>(
      externalName: "md5",
      defaultValue: nil,
      keyPath: \Rom.md5
    )
    
    /// Type information for property ``Rom/crc`` (`crc` column).
    public let crc = MappedColumn<Rom, String?>(
      externalName: "crc",
      defaultValue: nil,
      keyPath: \Rom.crc
    )
    
    /// Type information for property ``Rom/sha1`` (`sha1` column).
    public let sha1 = MappedColumn<Rom, String?>(
      externalName: "sha1",
      defaultValue: nil,
      keyPath: \Rom.sha1
    )
    
    /// Type information for property ``Rom/size`` (`size` column).
    public let size = MappedColumn<Rom, Int>(externalName: "size", defaultValue: -1, keyPath: \Rom.size)
    
    /// Type information for property ``Rom/gameId`` (`game_id` column).
    public let gameId = MappedForeignKey<Rom, Int, MappedColumn<Game, Int?>>(
      externalName: "game_id",
      defaultValue: -1,
      keyPath: \Rom.gameId,
      destinationColumn: Game.schema.id
    )
    
    #if swift(>=5.7)
    public var _allColumns : [ any SQLColumn ] { [ fileName, mimetype, md5, crc, sha1, size, gameId ] }
    #endif // swift(>=5.7)
    
    public init()
    {
    }
  }
  
  /**
   * Initialize a ``Rom`` record from a SQLite statement handle.
   * 
   * This initializer allows easy setup of a record structure from an
   * otherwise arbitrarily constructed SQLite prepared statement.
   * 
   * If no `indices` are specified, the `Schema/lookupColumnIndices`
   * function will be used to find the positions of the structure properties
   * based on their external name.
   * When looping, it is recommended to do the lookup once, and then
   * provide the `indices` to the initializer.
   * 
   * Required values that are missing in the statement are replaced with
   * their assigned default values, i.e. this can even be used to perform
   * partial selects w/ only a minor overhead (the extra space for a
   * record).
   * 
   * Example:
   * ```swift
   * var statement : OpaquePointer?
   * sqlite3_prepare_v2(dbHandle, "SELECT * FROM rom", -1, &statement, nil)
   * while sqlite3_step(statement) == SQLITE_ROW {
   *   let record = Rom(statement)
   *   print("Fetched:", record)
   * }
   * sqlite3_finalize(statement)
   * ```
   * 
   * - Parameters:
   *   - statement: Statement handle as returned by `sqlite3_prepare*` functions.
   *   - indices: Property bindings positions, defaults to `nil` (automatic lookup).
   */
  @inlinable
  init(_ statement: OpaquePointer!, indices: Schema.PropertyIndices? = nil)
  {
    let indices = indices ?? Self.Schema.lookupColumnIndices(in: statement)
    let argc = sqlite3_column_count(statement)
    self.init(
      fileName: ((indices.idx_fileName >= 0) && (indices.idx_fileName < argc) ? (sqlite3_column_text(statement, indices.idx_fileName).flatMap(String.init(cString:))) : nil) ?? Self.schema.fileName.defaultValue,
      mimetype: (indices.idx_mimetype >= 0) && (indices.idx_mimetype < argc) ? (sqlite3_column_text(statement, indices.idx_mimetype).flatMap(String.init(cString:))) : Self.schema.mimetype.defaultValue,
      md5: (indices.idx_md5 >= 0) && (indices.idx_md5 < argc) ? (sqlite3_column_text(statement, indices.idx_md5).flatMap(String.init(cString:))) : Self.schema.md5.defaultValue,
      crc: (indices.idx_crc >= 0) && (indices.idx_crc < argc) ? (sqlite3_column_text(statement, indices.idx_crc).flatMap(String.init(cString:))) : Self.schema.crc.defaultValue,
      sha1: (indices.idx_sha1 >= 0) && (indices.idx_sha1 < argc) ? (sqlite3_column_text(statement, indices.idx_sha1).flatMap(String.init(cString:))) : Self.schema.sha1.defaultValue,
      size: (indices.idx_size >= 0) && (indices.idx_size < argc) && (sqlite3_column_type(statement, indices.idx_size) != SQLITE_NULL) ? Int(sqlite3_column_int64(statement, indices.idx_size)) : Self.schema.size.defaultValue,
      gameId: (indices.idx_gameId >= 0) && (indices.idx_gameId < argc) && (sqlite3_column_type(statement, indices.idx_gameId) != SQLITE_NULL) ? Int(sqlite3_column_int64(statement, indices.idx_gameId)) : Self.schema.gameId.defaultValue
    )
  }
  
  /**
   * Bind all ``Rom`` properties to a prepared statement and call a closure.
   * 
   * *Important*: The bindings are only valid within the closure being executed!
   * 
   * Example:
   * ```swift
   * var statement : OpaquePointer?
   * sqlite3_prepare_v2(
   *   dbHandle,
   *   #"UPDATE rom SET lastname = ?, firstname = ? WHERE person_id = ?"#,
   *   -1, &statement, nil
   * )
   * 
   * let record = Rom(fileName: "Hello", mimetype: "World", md5: "Duck", crc: "Donald", sha1: "Mickey", size: 1, gameId: 2)
   * let ok = record.bind(to: statement, indices: ( 1, 2, 3, 4, 5, 6, 7 )) {
   *   sqlite3_step(statement) == SQLITE_DONE
   * }
   * sqlite3_finalize(statement)
   * ```
   * 
   * - Parameters:
   *   - statement: A SQLite3 statement handle as returned by the `sqlite3_prepare*` functions.
   *   - indices: The parameter positions for the bindings.
   *   - execute: Closure executed with bindings applied, bindings _only_ valid within the call!
   * - Returns: Returns the result of the closure that is passed in.
   */
  @inlinable
  @discardableResult
  func bind<R>(
    to statement: OpaquePointer!,
    indices: Schema.PropertyIndices,
    then execute: () throws -> R
  ) rethrows -> R
  {
    return try fileName.withCString() { ( s ) in
      if indices.idx_fileName >= 0 {
        sqlite3_bind_text(statement, indices.idx_fileName, s, -1, nil)
      }
      return try ShiragameSchema.withOptCString(mimetype) { ( s ) in
        if indices.idx_mimetype >= 0 {
          sqlite3_bind_text(statement, indices.idx_mimetype, s, -1, nil)
        }
        return try ShiragameSchema.withOptCString(md5) { ( s ) in
          if indices.idx_md5 >= 0 {
            sqlite3_bind_text(statement, indices.idx_md5, s, -1, nil)
          }
          return try ShiragameSchema.withOptCString(crc) { ( s ) in
            if indices.idx_crc >= 0 {
              sqlite3_bind_text(statement, indices.idx_crc, s, -1, nil)
            }
            return try ShiragameSchema.withOptCString(sha1) { ( s ) in
              if indices.idx_sha1 >= 0 {
                sqlite3_bind_text(statement, indices.idx_sha1, s, -1, nil)
              }
              if indices.idx_size >= 0 {
                sqlite3_bind_int64(statement, indices.idx_size, Int64(size))
              }
              if indices.idx_gameId >= 0 {
                sqlite3_bind_int64(statement, indices.idx_gameId, Int64(gameId))
              }
              return try execute()
            }
          }
        }
      }
    }
  }
}

public extension Serial {
  
  /**
   * Static type information for the ``Serial`` record (`serial` SQL table).
   * 
   * This structure captures the static SQL information associated with the
   * record.
   * It is used for static type lookups and more.
   */
  struct Schema : SQLTableSchema, SQLSwiftMatchableSchema, SQLCreatableSchema {
    
    public typealias PropertyIndices = ( idx_serial: Int32, idx_normalized: Int32, idx_gameId: Int32 )
    public typealias RecordType = Serial
    public typealias MatchClosureType = ( Serial ) -> Bool
    
    /// The SQL table name associated with the ``Serial`` record.
    public static let externalName = "serial"
    
    /// The number of columns the `serial` table has.
    public static let columnCount : Int32 = 3
    
    /// The SQL used to create the `serial` table.
    public static let create = 
      #"""
      CREATE TABLE serial ( 
              serial TEXT NOT NULL,
              normalized TEXT NOT NULL,
              game_id INTEGER NOT NULL,
              FOREIGN KEY (game_id) REFERENCES game (game_id)
          );
      """#
    
    /// SQL to `SELECT` all columns of the `serial` table.
    public static let select = #"SELECT "serial", "normalized", "game_id" FROM "serial""#
    
    /// SQL fragment representing all columns.
    public static let selectColumns = #""serial", "normalized", "game_id""#
    
    /// Index positions of the properties in ``selectColumns``.
    public static let selectColumnIndices : PropertyIndices = ( 0, 1, 2 )
    
    /// SQL to `SELECT` all columns of the `serial` table using a Swift filter.
    public static let matchSelect = #"SELECT "serial", "normalized", "game_id" FROM "serial" WHERE serials_swift_match("serial", "normalized", "game_id") != 0"#
    
    /// SQL to `INSERT` a record into the `serial` table.
    public static let insert = #"INSERT INTO "serial" ( "serial", "normalized", "game_id" ) VALUES ( ?, ?, ? )"#
    
    /// SQL to `INSERT` a record into the `serial` table.
    public static let insertReturning = #"INSERT INTO "serial" ( "serial", "normalized", "game_id" ) VALUES ( ?, ?, ? ) RETURNING "serial", "normalized", "game_id""#
    
    /// Property parameter indicies in the ``insert`` SQL
    public static let insertParameterIndices : PropertyIndices = ( 1, 2, 3 )
    
    /// SQL to `DELETE` a record from the `serial` table.
    public static let delete = #"DELETE FROM "serial" WHERE "serial" = ? AND "normalized" = ? AND "game_id" = ?"#
    
    /// Property parameter indicies in the ``delete`` SQL
    public static let deleteParameterIndices : PropertyIndices = ( 1, 2, 3 )
    
    /**
     * Lookup property indices by column name in a statement handle.
     * 
     * Properties are ordered in the schema and have a specific index
     * assigned.
     * E.g. if the record has two properties, `id` and `name`,
     * and the query was `SELECT age, serial_id FROM serial`,
     * this would return `( idx_id: 1, idx_name: -1 )`.
     * Because the `serial_id` is in the second position and `name`
     * isn't provided at all.
     * 
     * - Parameters:
     *   - statement: A raw SQLite3 prepared statement handle.
     * - Returns: The positions of the properties in the prepared statement.
     */
    @inlinable
    public static func lookupColumnIndices(`in` statement: OpaquePointer!)
      -> PropertyIndices
    {
      var indices : PropertyIndices = ( -1, -1, -1 )
      for i in 0..<sqlite3_column_count(statement) {
        let col = sqlite3_column_name(statement, i)
        if strcmp(col!, "serial") == 0 {
          indices.idx_serial = i
        }
        else if strcmp(col!, "normalized") == 0 {
          indices.idx_normalized = i
        }
        else if strcmp(col!, "game_id") == 0 {
          indices.idx_gameId = i
        }
      }
      return indices
    }
    
    /**
     * Register the Swift matcher function for the ``Serial`` record.
     * 
     * SQLite Swift matcher functions are used to process `filter` queries
     * and low-level matching w/o the Lighter library.
     * 
     * - Parameters:
     *   - unsafeDatabaseHandle: SQLite3 database handle.
     *   - flags: SQLite3 function registration flags, default: `SQLITE_UTF8`
     *   - matcher: A pointer to the Swift closure used to filter the records.
     * - Returns: The result code of `sqlite3_create_function`, e.g. `SQLITE_OK`.
     */
    @inlinable
    @discardableResult
    public static func registerSwiftMatcher(
      `in` unsafeDatabaseHandle: OpaquePointer!,
      flags: Int32 = SQLITE_UTF8,
      matcher: UnsafeRawPointer
    ) -> Int32
    {
      func dispatch(
        _ context: OpaquePointer?,
        argc: Int32,
        argv: UnsafeMutablePointer<OpaquePointer?>!
      )
      {
        if let closureRawPtr = sqlite3_user_data(context) {
          let closurePtr = closureRawPtr.bindMemory(to: MatchClosureType.self, capacity: 1)
          let indices = Serial.Schema.selectColumnIndices
          let record = Serial(
            serial: ((indices.idx_serial >= 0) && (indices.idx_serial < argc) ? (sqlite3_value_text(argv[Int(indices.idx_serial)]).flatMap(String.init(cString:))) : nil) ?? RecordType.schema.serial.defaultValue,
            normalized: ((indices.idx_normalized >= 0) && (indices.idx_normalized < argc) ? (sqlite3_value_text(argv[Int(indices.idx_normalized)]).flatMap(String.init(cString:))) : nil) ?? RecordType.schema.normalized.defaultValue,
            gameId: (indices.idx_gameId >= 0) && (indices.idx_gameId < argc) && (sqlite3_value_type(argv[Int(indices.idx_gameId)]) != SQLITE_NULL) ? Int(sqlite3_value_int64(argv[Int(indices.idx_gameId)])) : RecordType.schema.gameId.defaultValue
          )
          sqlite3_result_int(context, closurePtr.pointee(record) ? 1 : 0)
        }
        else {
          sqlite3_result_error(context, "Missing Swift matcher closure", -1)
        }
      }
      return sqlite3_create_function(
        unsafeDatabaseHandle,
        "serials_swift_match",
        Serial.Schema.columnCount,
        flags,
        UnsafeMutableRawPointer(mutating: matcher),
        dispatch,
        nil,
        nil
      )
    }
    
    /**
     * Unregister the Swift matcher function for the ``Serial`` record.
     * 
     * SQLite Swift matcher functions are used to process `filter` queries
     * and low-level matching w/o the Lighter library.
     * 
     * - Parameters:
     *   - unsafeDatabaseHandle: SQLite3 database handle.
     *   - flags: SQLite3 function registration flags, default: `SQLITE_UTF8`
     * - Returns: The result code of `sqlite3_create_function`, e.g. `SQLITE_OK`.
     */
    @inlinable
    @discardableResult
    public static func unregisterSwiftMatcher(
      `in` unsafeDatabaseHandle: OpaquePointer!,
      flags: Int32 = SQLITE_UTF8
    ) -> Int32
    {
      sqlite3_create_function(
        unsafeDatabaseHandle,
        "serials_swift_match",
        Serial.Schema.columnCount,
        flags,
        nil,
        nil,
        nil,
        nil
      )
    }
    
    /// Type information for property ``Serial/serial`` (`serial` column).
    public let serial = MappedColumn<Serial, String>(
      externalName: "serial",
      defaultValue: "",
      keyPath: \Serial.serial
    )
    
    /// Type information for property ``Serial/normalized`` (`normalized` column).
    public let normalized = MappedColumn<Serial, String>(
      externalName: "normalized",
      defaultValue: "",
      keyPath: \Serial.normalized
    )
    
    /// Type information for property ``Serial/gameId`` (`game_id` column).
    public let gameId = MappedForeignKey<Serial, Int, MappedColumn<Game, Int?>>(
      externalName: "game_id",
      defaultValue: -1,
      keyPath: \Serial.gameId,
      destinationColumn: Game.schema.id
    )
    
    #if swift(>=5.7)
    public var _allColumns : [ any SQLColumn ] { [ serial, normalized, gameId ] }
    #endif // swift(>=5.7)
    
    public init()
    {
    }
  }
  
  /**
   * Initialize a ``Serial`` record from a SQLite statement handle.
   * 
   * This initializer allows easy setup of a record structure from an
   * otherwise arbitrarily constructed SQLite prepared statement.
   * 
   * If no `indices` are specified, the `Schema/lookupColumnIndices`
   * function will be used to find the positions of the structure properties
   * based on their external name.
   * When looping, it is recommended to do the lookup once, and then
   * provide the `indices` to the initializer.
   * 
   * Required values that are missing in the statement are replaced with
   * their assigned default values, i.e. this can even be used to perform
   * partial selects w/ only a minor overhead (the extra space for a
   * record).
   * 
   * Example:
   * ```swift
   * var statement : OpaquePointer?
   * sqlite3_prepare_v2(dbHandle, "SELECT * FROM serial", -1, &statement, nil)
   * while sqlite3_step(statement) == SQLITE_ROW {
   *   let record = Serial(statement)
   *   print("Fetched:", record)
   * }
   * sqlite3_finalize(statement)
   * ```
   * 
   * - Parameters:
   *   - statement: Statement handle as returned by `sqlite3_prepare*` functions.
   *   - indices: Property bindings positions, defaults to `nil` (automatic lookup).
   */
  @inlinable
  init(_ statement: OpaquePointer!, indices: Schema.PropertyIndices? = nil)
  {
    let indices = indices ?? Self.Schema.lookupColumnIndices(in: statement)
    let argc = sqlite3_column_count(statement)
    self.init(
      serial: ((indices.idx_serial >= 0) && (indices.idx_serial < argc) ? (sqlite3_column_text(statement, indices.idx_serial).flatMap(String.init(cString:))) : nil) ?? Self.schema.serial.defaultValue,
      normalized: ((indices.idx_normalized >= 0) && (indices.idx_normalized < argc) ? (sqlite3_column_text(statement, indices.idx_normalized).flatMap(String.init(cString:))) : nil) ?? Self.schema.normalized.defaultValue,
      gameId: (indices.idx_gameId >= 0) && (indices.idx_gameId < argc) && (sqlite3_column_type(statement, indices.idx_gameId) != SQLITE_NULL) ? Int(sqlite3_column_int64(statement, indices.idx_gameId)) : Self.schema.gameId.defaultValue
    )
  }
  
  /**
   * Bind all ``Serial`` properties to a prepared statement and call a closure.
   * 
   * *Important*: The bindings are only valid within the closure being executed!
   * 
   * Example:
   * ```swift
   * var statement : OpaquePointer?
   * sqlite3_prepare_v2(
   *   dbHandle,
   *   #"UPDATE serial SET lastname = ?, firstname = ? WHERE person_id = ?"#,
   *   -1, &statement, nil
   * )
   * 
   * let record = Serial(serial: "Hello", normalized: "World", gameId: 1)
   * let ok = record.bind(to: statement, indices: ( 1, 2, 3 )) {
   *   sqlite3_step(statement) == SQLITE_DONE
   * }
   * sqlite3_finalize(statement)
   * ```
   * 
   * - Parameters:
   *   - statement: A SQLite3 statement handle as returned by the `sqlite3_prepare*` functions.
   *   - indices: The parameter positions for the bindings.
   *   - execute: Closure executed with bindings applied, bindings _only_ valid within the call!
   * - Returns: Returns the result of the closure that is passed in.
   */
  @inlinable
  @discardableResult
  func bind<R>(
    to statement: OpaquePointer!,
    indices: Schema.PropertyIndices,
    then execute: () throws -> R
  ) rethrows -> R
  {
    return try serial.withCString() { ( s ) in
      if indices.idx_serial >= 0 {
        sqlite3_bind_text(statement, indices.idx_serial, s, -1, nil)
      }
      return try normalized.withCString() { ( s ) in
        if indices.idx_normalized >= 0 {
          sqlite3_bind_text(statement, indices.idx_normalized, s, -1, nil)
        }
        if indices.idx_gameId >= 0 {
          sqlite3_bind_int64(statement, indices.idx_gameId, Int64(gameId))
        }
        return try execute()
      }
    }
  }
}

public extension Shiragame {
  
  /**
   * Static type information for the ``Shiragame`` record (`shiragame` SQL table).
   * 
   * This structure captures the static SQL information associated with the
   * record.
   * It is used for static type lookups and more.
   */
  struct Schema : SQLTableSchema, SQLSwiftMatchableSchema, SQLCreatableSchema {
    
    public typealias PropertyIndices = ( idx_shiragame: Int32, idx_schemaVersion: Int32, idx_stoneVersion: Int32, idx_generated: Int32, idx_release: Int32, idx_aggregator: Int32 )
    public typealias RecordType = Shiragame
    public typealias MatchClosureType = ( Shiragame ) -> Bool
    
    /// The SQL table name associated with the ``Shiragame`` record.
    public static let externalName = "shiragame"
    
    /// The number of columns the `shiragame` table has.
    public static let columnCount : Int32 = 6
    
    /// The SQL used to create the `shiragame` table.
    public static let create = 
      #"""
      CREATE TABLE shiragame (
              shiragame TEXT,
              schema_version TEXT,
              stone_version TEXT,
              generated TEXT,
              release TEXT,
              aggregator TEXT
          );
      """#
    
    /// SQL to `SELECT` all columns of the `shiragame` table.
    public static let select = #"SELECT "shiragame", "schema_version", "stone_version", "generated", "release", "aggregator" FROM "shiragame""#
    
    /// SQL fragment representing all columns.
    public static let selectColumns = #""shiragame", "schema_version", "stone_version", "generated", "release", "aggregator""#
    
    /// Index positions of the properties in ``selectColumns``.
    public static let selectColumnIndices : PropertyIndices = ( 0, 1, 2, 3, 4, 5 )
    
    /// SQL to `SELECT` all columns of the `shiragame` table using a Swift filter.
    public static let matchSelect = #"SELECT "shiragame", "schema_version", "stone_version", "generated", "release", "aggregator" FROM "shiragame" WHERE shiragames_swift_match("shiragame", "schema_version", "stone_version", "generated", "release", "aggregator") != 0"#
    
    /// SQL to `INSERT` a record into the `shiragame` table.
    public static let insert = #"INSERT INTO "shiragame" ( "shiragame", "schema_version", "stone_version", "generated", "release", "aggregator" ) VALUES ( ?, ?, ?, ?, ?, ? )"#
    
    /// SQL to `INSERT` a record into the `shiragame` table.
    public static let insertReturning = #"INSERT INTO "shiragame" ( "shiragame", "schema_version", "stone_version", "generated", "release", "aggregator" ) VALUES ( ?, ?, ?, ?, ?, ? ) RETURNING "shiragame", "schema_version", "stone_version", "generated", "release", "aggregator""#
    
    /// Property parameter indicies in the ``insert`` SQL
    public static let insertParameterIndices : PropertyIndices = ( 1, 2, 3, 4, 5, 6 )
    
    /// SQL to `DELETE` a record from the `shiragame` table.
    public static let delete = #"DELETE FROM "shiragame" WHERE "shiragame" = ? AND "schema_version" = ? AND "stone_version" = ? AND "generated" = ? AND "release" = ? AND "aggregator" = ?"#
    
    /// Property parameter indicies in the ``delete`` SQL
    public static let deleteParameterIndices : PropertyIndices = ( 1, 2, 3, 4, 5, 6 )
    
    /**
     * Lookup property indices by column name in a statement handle.
     * 
     * Properties are ordered in the schema and have a specific index
     * assigned.
     * E.g. if the record has two properties, `id` and `name`,
     * and the query was `SELECT age, shiragame_id FROM shiragame`,
     * this would return `( idx_id: 1, idx_name: -1 )`.
     * Because the `shiragame_id` is in the second position and `name`
     * isn't provided at all.
     * 
     * - Parameters:
     *   - statement: A raw SQLite3 prepared statement handle.
     * - Returns: The positions of the properties in the prepared statement.
     */
    @inlinable
    public static func lookupColumnIndices(`in` statement: OpaquePointer!)
      -> PropertyIndices
    {
      var indices : PropertyIndices = ( -1, -1, -1, -1, -1, -1 )
      for i in 0..<sqlite3_column_count(statement) {
        let col = sqlite3_column_name(statement, i)
        if strcmp(col!, "shiragame") == 0 {
          indices.idx_shiragame = i
        }
        else if strcmp(col!, "schema_version") == 0 {
          indices.idx_schemaVersion = i
        }
        else if strcmp(col!, "stone_version") == 0 {
          indices.idx_stoneVersion = i
        }
        else if strcmp(col!, "generated") == 0 {
          indices.idx_generated = i
        }
        else if strcmp(col!, "release") == 0 {
          indices.idx_release = i
        }
        else if strcmp(col!, "aggregator") == 0 {
          indices.idx_aggregator = i
        }
      }
      return indices
    }
    
    /**
     * Register the Swift matcher function for the ``Shiragame`` record.
     * 
     * SQLite Swift matcher functions are used to process `filter` queries
     * and low-level matching w/o the Lighter library.
     * 
     * - Parameters:
     *   - unsafeDatabaseHandle: SQLite3 database handle.
     *   - flags: SQLite3 function registration flags, default: `SQLITE_UTF8`
     *   - matcher: A pointer to the Swift closure used to filter the records.
     * - Returns: The result code of `sqlite3_create_function`, e.g. `SQLITE_OK`.
     */
    @inlinable
    @discardableResult
    public static func registerSwiftMatcher(
      `in` unsafeDatabaseHandle: OpaquePointer!,
      flags: Int32 = SQLITE_UTF8,
      matcher: UnsafeRawPointer
    ) -> Int32
    {
      func dispatch(
        _ context: OpaquePointer?,
        argc: Int32,
        argv: UnsafeMutablePointer<OpaquePointer?>!
      )
      {
        if let closureRawPtr = sqlite3_user_data(context) {
          let closurePtr = closureRawPtr.bindMemory(to: MatchClosureType.self, capacity: 1)
          let indices = Shiragame.Schema.selectColumnIndices
          let record = Shiragame(
            shiragame: (indices.idx_shiragame >= 0) && (indices.idx_shiragame < argc) ? (sqlite3_value_text(argv[Int(indices.idx_shiragame)]).flatMap(String.init(cString:))) : RecordType.schema.shiragame.defaultValue,
            schemaVersion: (indices.idx_schemaVersion >= 0) && (indices.idx_schemaVersion < argc) ? (sqlite3_value_text(argv[Int(indices.idx_schemaVersion)]).flatMap(String.init(cString:))) : RecordType.schema.schemaVersion.defaultValue,
            stoneVersion: (indices.idx_stoneVersion >= 0) && (indices.idx_stoneVersion < argc) ? (sqlite3_value_text(argv[Int(indices.idx_stoneVersion)]).flatMap(String.init(cString:))) : RecordType.schema.stoneVersion.defaultValue,
            generated: (indices.idx_generated >= 0) && (indices.idx_generated < argc) ? (sqlite3_value_text(argv[Int(indices.idx_generated)]).flatMap(String.init(cString:))) : RecordType.schema.generated.defaultValue,
            release: (indices.idx_release >= 0) && (indices.idx_release < argc) ? (sqlite3_value_text(argv[Int(indices.idx_release)]).flatMap(String.init(cString:))) : RecordType.schema.release.defaultValue,
            aggregator: (indices.idx_aggregator >= 0) && (indices.idx_aggregator < argc) ? (sqlite3_value_text(argv[Int(indices.idx_aggregator)]).flatMap(String.init(cString:))) : RecordType.schema.aggregator.defaultValue
          )
          sqlite3_result_int(context, closurePtr.pointee(record) ? 1 : 0)
        }
        else {
          sqlite3_result_error(context, "Missing Swift matcher closure", -1)
        }
      }
      return sqlite3_create_function(
        unsafeDatabaseHandle,
        "shiragames_swift_match",
        Shiragame.Schema.columnCount,
        flags,
        UnsafeMutableRawPointer(mutating: matcher),
        dispatch,
        nil,
        nil
      )
    }
    
    /**
     * Unregister the Swift matcher function for the ``Shiragame`` record.
     * 
     * SQLite Swift matcher functions are used to process `filter` queries
     * and low-level matching w/o the Lighter library.
     * 
     * - Parameters:
     *   - unsafeDatabaseHandle: SQLite3 database handle.
     *   - flags: SQLite3 function registration flags, default: `SQLITE_UTF8`
     * - Returns: The result code of `sqlite3_create_function`, e.g. `SQLITE_OK`.
     */
    @inlinable
    @discardableResult
    public static func unregisterSwiftMatcher(
      `in` unsafeDatabaseHandle: OpaquePointer!,
      flags: Int32 = SQLITE_UTF8
    ) -> Int32
    {
      sqlite3_create_function(
        unsafeDatabaseHandle,
        "shiragames_swift_match",
        Shiragame.Schema.columnCount,
        flags,
        nil,
        nil,
        nil,
        nil
      )
    }
    
    /// Type information for property ``Shiragame/shiragame`` (`shiragame` column).
    public let shiragame = MappedColumn<Shiragame, String?>(
      externalName: "shiragame",
      defaultValue: nil,
      keyPath: \Shiragame.shiragame
    )
    
    /// Type information for property ``Shiragame/schemaVersion`` (`schema_version` column).
    public let schemaVersion = MappedColumn<Shiragame, String?>(
      externalName: "schema_version",
      defaultValue: nil,
      keyPath: \Shiragame.schemaVersion
    )
    
    /// Type information for property ``Shiragame/stoneVersion`` (`stone_version` column).
    public let stoneVersion = MappedColumn<Shiragame, String?>(
      externalName: "stone_version",
      defaultValue: nil,
      keyPath: \Shiragame.stoneVersion
    )
    
    /// Type information for property ``Shiragame/generated`` (`generated` column).
    public let generated = MappedColumn<Shiragame, String?>(
      externalName: "generated",
      defaultValue: nil,
      keyPath: \Shiragame.generated
    )
    
    /// Type information for property ``Shiragame/release`` (`release` column).
    public let release = MappedColumn<Shiragame, String?>(
      externalName: "release",
      defaultValue: nil,
      keyPath: \Shiragame.release
    )
    
    /// Type information for property ``Shiragame/aggregator`` (`aggregator` column).
    public let aggregator = MappedColumn<Shiragame, String?>(
      externalName: "aggregator",
      defaultValue: nil,
      keyPath: \Shiragame.aggregator
    )
    
    #if swift(>=5.7)
    public var _allColumns : [ any SQLColumn ] { [ shiragame, schemaVersion, stoneVersion, generated, release, aggregator ] }
    #endif // swift(>=5.7)
    
    public init()
    {
    }
  }
  
  /**
   * Initialize a ``Shiragame`` record from a SQLite statement handle.
   * 
   * This initializer allows easy setup of a record structure from an
   * otherwise arbitrarily constructed SQLite prepared statement.
   * 
   * If no `indices` are specified, the `Schema/lookupColumnIndices`
   * function will be used to find the positions of the structure properties
   * based on their external name.
   * When looping, it is recommended to do the lookup once, and then
   * provide the `indices` to the initializer.
   * 
   * Required values that are missing in the statement are replaced with
   * their assigned default values, i.e. this can even be used to perform
   * partial selects w/ only a minor overhead (the extra space for a
   * record).
   * 
   * Example:
   * ```swift
   * var statement : OpaquePointer?
   * sqlite3_prepare_v2(dbHandle, "SELECT * FROM shiragame", -1, &statement, nil)
   * while sqlite3_step(statement) == SQLITE_ROW {
   *   let record = Shiragame(statement)
   *   print("Fetched:", record)
   * }
   * sqlite3_finalize(statement)
   * ```
   * 
   * - Parameters:
   *   - statement: Statement handle as returned by `sqlite3_prepare*` functions.
   *   - indices: Property bindings positions, defaults to `nil` (automatic lookup).
   */
  @inlinable
  init(_ statement: OpaquePointer!, indices: Schema.PropertyIndices? = nil)
  {
    let indices = indices ?? Self.Schema.lookupColumnIndices(in: statement)
    let argc = sqlite3_column_count(statement)
    self.init(
      shiragame: (indices.idx_shiragame >= 0) && (indices.idx_shiragame < argc) ? (sqlite3_column_text(statement, indices.idx_shiragame).flatMap(String.init(cString:))) : Self.schema.shiragame.defaultValue,
      schemaVersion: (indices.idx_schemaVersion >= 0) && (indices.idx_schemaVersion < argc) ? (sqlite3_column_text(statement, indices.idx_schemaVersion).flatMap(String.init(cString:))) : Self.schema.schemaVersion.defaultValue,
      stoneVersion: (indices.idx_stoneVersion >= 0) && (indices.idx_stoneVersion < argc) ? (sqlite3_column_text(statement, indices.idx_stoneVersion).flatMap(String.init(cString:))) : Self.schema.stoneVersion.defaultValue,
      generated: (indices.idx_generated >= 0) && (indices.idx_generated < argc) ? (sqlite3_column_text(statement, indices.idx_generated).flatMap(String.init(cString:))) : Self.schema.generated.defaultValue,
      release: (indices.idx_release >= 0) && (indices.idx_release < argc) ? (sqlite3_column_text(statement, indices.idx_release).flatMap(String.init(cString:))) : Self.schema.release.defaultValue,
      aggregator: (indices.idx_aggregator >= 0) && (indices.idx_aggregator < argc) ? (sqlite3_column_text(statement, indices.idx_aggregator).flatMap(String.init(cString:))) : Self.schema.aggregator.defaultValue
    )
  }
  
  /**
   * Bind all ``Shiragame`` properties to a prepared statement and call a closure.
   * 
   * *Important*: The bindings are only valid within the closure being executed!
   * 
   * Example:
   * ```swift
   * var statement : OpaquePointer?
   * sqlite3_prepare_v2(
   *   dbHandle,
   *   #"UPDATE shiragame SET lastname = ?, firstname = ? WHERE person_id = ?"#,
   *   -1, &statement, nil
   * )
   * 
   * let record = Shiragame(shiragame: "Hello", schemaVersion: "World", stoneVersion: "Duck", generated: "Donald")
   * let ok = record.bind(to: statement, indices: ( 1, 2, 3, 4, 5, 6 )) {
   *   sqlite3_step(statement) == SQLITE_DONE
   * }
   * sqlite3_finalize(statement)
   * ```
   * 
   * - Parameters:
   *   - statement: A SQLite3 statement handle as returned by the `sqlite3_prepare*` functions.
   *   - indices: The parameter positions for the bindings.
   *   - execute: Closure executed with bindings applied, bindings _only_ valid within the call!
   * - Returns: Returns the result of the closure that is passed in.
   */
  @inlinable
  @discardableResult
  func bind<R>(
    to statement: OpaquePointer!,
    indices: Schema.PropertyIndices,
    then execute: () throws -> R
  ) rethrows -> R
  {
    return try ShiragameSchema.withOptCString(shiragame) { ( s ) in
      if indices.idx_shiragame >= 0 {
        sqlite3_bind_text(statement, indices.idx_shiragame, s, -1, nil)
      }
      return try ShiragameSchema.withOptCString(schemaVersion) { ( s ) in
        if indices.idx_schemaVersion >= 0 {
          sqlite3_bind_text(statement, indices.idx_schemaVersion, s, -1, nil)
        }
        return try ShiragameSchema.withOptCString(stoneVersion) { ( s ) in
          if indices.idx_stoneVersion >= 0 {
            sqlite3_bind_text(statement, indices.idx_stoneVersion, s, -1, nil)
          }
          return try ShiragameSchema.withOptCString(generated) { ( s ) in
            if indices.idx_generated >= 0 {
              sqlite3_bind_text(statement, indices.idx_generated, s, -1, nil)
            }
            return try ShiragameSchema.withOptCString(release) { ( s ) in
              if indices.idx_release >= 0 {
                sqlite3_bind_text(statement, indices.idx_release, s, -1, nil)
              }
              return try ShiragameSchema.withOptCString(aggregator) { ( s ) in
                if indices.idx_aggregator >= 0 {
                  sqlite3_bind_text(statement, indices.idx_aggregator, s, -1, nil)
                }
                return try execute()
              }
            }
          }
        }
      }
    }
  }
}

public extension SQLRecordFetchOperations
  where T == Game, Ops: SQLDatabaseFetchOperations, Ops.RecordTypes == ShiragameSchema.RecordTypes
{
  
  /**
   * Fetch the ``Game`` record related to a ``Rom`` (`gameId`).
   * 
   * This fetches the related ``Game`` record using the
   * ``Rom/gameId`` property.
   * 
   * Example:
   * ```swift
   * let sourceRecord  : Rom = ...
   * let relatedRecord = try db.games.find(for: sourceRecord)
   * ```
   * 
   * - Parameters:
   *   - record: The ``Rom`` record.
   * - Returns: The related ``Game`` record (throws if not found).
   */
  @inlinable
  func find(`for` record: Rom) throws -> Game
  {
    if let record = try operations[dynamicMember: \.roms].findTarget(for: \.gameId, in: record) {
      return record
    }
    else {
      throw LighterError(.couldNotFindRelationshipTarget, SQLITE_CONSTRAINT)
    }
  }
  
  /**
   * Fetch the ``Game`` record related to a ``Serial`` (`gameId`).
   * 
   * This fetches the related ``Game`` record using the
   * ``Serial/gameId`` property.
   * 
   * Example:
   * ```swift
   * let sourceRecord  : Serial = ...
   * let relatedRecord = try db.games.find(for: sourceRecord)
   * ```
   * 
   * - Parameters:
   *   - record: The ``Serial`` record.
   * - Returns: The related ``Game`` record (throws if not found).
   */
  @inlinable
  func find(`for` record: Serial) throws -> Game
  {
    if let record = try operations[dynamicMember: \.serials].findTarget(for: \.gameId, in: record) {
      return record
    }
    else {
      throw LighterError(.couldNotFindRelationshipTarget, SQLITE_CONSTRAINT)
    }
  }
}

public extension SQLRecordFetchOperations
  where T == Rom, Ops: SQLDatabaseFetchOperations, Ops.RecordTypes == ShiragameSchema.RecordTypes
{
  
  /**
   * Fetches the ``Rom`` records related to a ``Game`` (`gameId`).
   * 
   * This fetches the related ``Game`` records using the
   * ``Rom/gameId`` property.
   * 
   * Example:
   * ```swift
   * let record         : Game = ...
   * let relatedRecords = try db.roms.fetch(for: record)
   * ```
   * 
   * - Parameters:
   *   - record: The ``Game`` record.
   *   - limit: An optional limit of records to fetch (defaults to `nil`).
   * - Returns: The related ``Game`` records.
   */
  @inlinable
  func fetch(`for` record: Game, limit: Int? = nil) throws -> [ Rom ]
  {
    try fetch(for: \.gameId, in: record, limit: limit)
  }
}

public extension SQLRecordFetchOperations
  where T == Serial, Ops: SQLDatabaseFetchOperations, Ops.RecordTypes == ShiragameSchema.RecordTypes
{
  
  /**
   * Fetches the ``Serial`` records related to a ``Game`` (`gameId`).
   * 
   * This fetches the related ``Game`` records using the
   * ``Serial/gameId`` property.
   * 
   * Example:
   * ```swift
   * let record         : Game = ...
   * let relatedRecords = try db.serials.fetch(for: record)
   * ```
   * 
   * - Parameters:
   *   - record: The ``Game`` record.
   *   - limit: An optional limit of records to fetch (defaults to `nil`).
   * - Returns: The related ``Game`` records.
   */
  @inlinable
  func fetch(`for` record: Game, limit: Int? = nil) throws -> [ Serial ]
  {
    try fetch(for: \.gameId, in: record, limit: limit)
  }
}

#if swift(>=5.5)
#if canImport(_Concurrency)
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public extension SQLRecordFetchOperations
  where T == Game, Ops: SQLDatabaseFetchOperations & SQLDatabaseAsyncOperations, Ops.RecordTypes == ShiragameSchema.RecordTypes
{
  
  /**
   * Fetch the ``Game`` record related to a ``Rom`` (`gameId`).
   * 
   * This fetches the related ``Game`` record using the
   * ``Rom/gameId`` property.
   * 
   * Example:
   * ```swift
   * let sourceRecord  : Rom = ...
   * let relatedRecord = try await db.games.find(for: sourceRecord)
   * ```
   * 
   * - Parameters:
   *   - record: The ``Rom`` record.
   * - Returns: The related ``Game`` record (throws if not found).
   */
  @inlinable
  func find(`for` record: Rom) async throws -> Game
  {
    if let record = try await operations[dynamicMember: \.roms].findTarget(for: \.gameId, in: record) {
      return record
    }
    else {
      throw LighterError(.couldNotFindRelationshipTarget, SQLITE_CONSTRAINT)
    }
  }
  
  /**
   * Fetch the ``Game`` record related to a ``Serial`` (`gameId`).
   * 
   * This fetches the related ``Game`` record using the
   * ``Serial/gameId`` property.
   * 
   * Example:
   * ```swift
   * let sourceRecord  : Serial = ...
   * let relatedRecord = try await db.games.find(for: sourceRecord)
   * ```
   * 
   * - Parameters:
   *   - record: The ``Serial`` record.
   * - Returns: The related ``Game`` record (throws if not found).
   */
  @inlinable
  func find(`for` record: Serial) async throws -> Game
  {
    if let record = try await operations[dynamicMember: \.serials].findTarget(
      for: \.gameId,
      in: record
    ) {
      return record
    }
    else {
      throw LighterError(.couldNotFindRelationshipTarget, SQLITE_CONSTRAINT)
    }
  }
}
#endif // required canImports
#endif // swift(>=5.5)

#if swift(>=5.5)
#if canImport(_Concurrency)
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public extension SQLRecordFetchOperations
  where T == Rom, Ops: SQLDatabaseFetchOperations & SQLDatabaseAsyncOperations, Ops.RecordTypes == ShiragameSchema.RecordTypes
{
  
  /**
   * Fetches the ``Rom`` records related to a ``Game`` (`gameId`).
   * 
   * This fetches the related ``Game`` records using the
   * ``Rom/gameId`` property.
   * 
   * Example:
   * ```swift
   * let record         : Game = ...
   * let relatedRecords = try await db.roms.fetch(for: record)
   * ```
   * 
   * - Parameters:
   *   - record: The ``Game`` record.
   *   - limit: An optional limit of records to fetch (defaults to `nil`).
   * - Returns: The related ``Game`` records.
   */
  @inlinable
  func fetch(`for` record: Game, limit: Int? = nil) async throws -> [ Rom ]
  {
    try await fetch(for: \.gameId, in: record, limit: limit)
  }
}
#endif // required canImports
#endif // swift(>=5.5)

#if swift(>=5.5)
#if canImport(_Concurrency)
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public extension SQLRecordFetchOperations
  where T == Serial, Ops: SQLDatabaseFetchOperations & SQLDatabaseAsyncOperations, Ops.RecordTypes == ShiragameSchema.RecordTypes
{
  
  /**
   * Fetches the ``Serial`` records related to a ``Game`` (`gameId`).
   * 
   * This fetches the related ``Game`` records using the
   * ``Serial/gameId`` property.
   * 
   * Example:
   * ```swift
   * let record         : Game = ...
   * let relatedRecords = try await db.serials.fetch(for: record)
   * ```
   * 
   * - Parameters:
   *   - record: The ``Game`` record.
   *   - limit: An optional limit of records to fetch (defaults to `nil`).
   * - Returns: The related ``Game`` records.
   */
  @inlinable
  func fetch(`for` record: Game, limit: Int? = nil) async throws -> [ Serial ]
  {
    try await fetch(for: \.gameId, in: record, limit: limit)
  }
}
#endif // required canImports
#endif // swift(>=5.5)
