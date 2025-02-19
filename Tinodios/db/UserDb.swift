//
//  UserDb.swift
//  ios
//
//  Copyright © 2019 Tinode. All rights reserved.
//

import Foundation
import SQLite
import TinodeSDK

class StoredUser: Payload {
    let id: Int64?
    init(id: Int64) { self.id = id }
}

class UserDb {
    private static let kTableName = "users"
    private let db: SQLite.Connection

    public let table: Table

    public let id: Expression<Int64>
    public let accountId: Expression<Int64?>
    public let uid: Expression<String?>
    public let updated: Expression<Date?>
    //public let deleted: Expression<Int?>
    public let pub: Expression<String?>

    private let baseDb: BaseDb!

    init(_ database: SQLite.Connection, baseDb: BaseDb) {
        self.db = database
        self.baseDb = baseDb
        self.table = Table(UserDb.kTableName)
        self.id = Expression<Int64>("id")
        self.accountId = Expression<Int64?>("account_id")
        self.uid = Expression<String?>("uid")
        self.updated = Expression<Date?>("updated")
        self.pub = Expression<String?>("pub")
    }
    func destroyTable() {
        try! self.db.run(self.table.dropIndex(accountId, uid, ifExists: true))
        try! self.db.run(self.table.drop(ifExists: true))
    }
    func createTable() {
        let accountDb = baseDb.accountDb!
        // Must succeed.
        try! self.db.run(self.table.create(ifNotExists: true) { t in
            t.column(id, primaryKey: .autoincrement)
            t.column(accountId, references: accountDb.table, accountDb.id)
            t.column(uid)
            t.column(updated)
            t.column(pub)
        })
        try! self.db.run(self.table.createIndex(accountId, uid, ifNotExists: true))
    }
    func insert(user: UserProto?) -> Int64 {
        guard let user = user else { return 0 }
        let id = self.insert(uid: user.uid, updated: user.updated, serializedPub: user.serializePub())
        if id > 0 {
            let su = StoredUser(id: id)
            user.payload = su
        }
        return id
    }
    @discardableResult
    func insert(sub: SubscriptionProto?) -> Int64 {
        guard let sub = sub else { return -1 }
        return self.insert(uid: sub.user ?? sub.topic, updated: sub.updated, serializedPub: sub.serializePub())
    }
    private func insert(uid: String?, updated: Date?, serializedPub: String?) -> Int64 {
        do {
            let rowid = try db.run(
                self.table.insert(
                    self.accountId <- baseDb.account?.id,
                    self.uid <- uid,
                    self.updated <- updated ?? Date(),
                    self.pub <- serializedPub
            ))
            return rowid
        } catch {
            Cache.log.error("UserDb - insert operation failed: uid = %{public}@, error = %{public}@", uid ?? "", error.localizedDescription)
            return -1
        }
    }
    @discardableResult
    func update(user: UserProto?) -> Bool {
        guard let user = user, let su = user.payload as? StoredUser, let userId = su.id, userId > 0 else { return false }
        return self.update(userId: userId, updated: user.updated, serializedPub: user.serializePub())
    }
    @discardableResult
    func update(sub: SubscriptionProto?) -> Bool {
        guard let st = sub?.payload as? StoredSubscription, let userId = st.userId else { return false }
        return self.update(userId: userId, updated: sub?.updated, serializedPub: sub?.serializePub())
    }
    @discardableResult
    func update(userId: Int64, updated: Date?, serializedPub: String?) -> Bool {
        var setters = [Setter]()
        if let u = updated {
            setters.append(self.updated <- u)
        }
        if let s = serializedPub {
            setters.append(self.pub <- s)
        }
        guard setters.count > 0 else { return false }
        let record = self.table.filter(self.id == userId)
        do {
            return try self.db.run(record.update(setters)) > 0
        } catch {
            Cache.log.error("UserDb - update operation failed: userId = %{public}@, error = %{public}@", userId, error.localizedDescription)
            return false
        }
    }
    @discardableResult
    func deleteRow(for id: Int64) -> Bool {
        let record = self.table.filter(self.id == id)
        do {
            return try self.db.run(record.delete()) > 0
        } catch {
            Cache.log.error("UserDb - deleteRow operation failed: userId = %{public}@, error = %{public}@", id, error.localizedDescription)
            return false
        }
    }
    func getId(for uid: String?) -> Int64 {
        guard let accountId = baseDb.account?.id else  {
            return -1
        }
        if let row = try? db.pluck(self.table.select(self.id).filter(self.uid == uid && self.accountId == accountId)) {
            return row[self.id]
        }
        return -1
    }
    private func rowToUser(r: Row) -> UserProto? {
        let id = r[self.id]
        let updated = r[self.updated]
        let pub = r[self.pub]
        guard let user = DefaultUser.createFromPublicData(uid: r[self.uid], updated: updated, data: pub) else { return nil }
        let storedUser = StoredUser(id: id)
        user.payload = storedUser
        return user
    }
    func readOne(uid: String?) -> UserProto? {
        guard let uid = uid, let accountId = baseDb.account?.id else {
            return nil
        }
        guard let row = try? db.pluck(self.table.filter(self.uid == uid && self.accountId == accountId)) else {
            return nil
        }
        return rowToUser(r: row)
    }

    // Generic reader
    private func read(one uid: String?, multiple uids: [String]) -> [UserProto]? {
        guard uid != nil || !uids.isEmpty else { return nil }
        guard let accountId = baseDb.account?.id else  {
            return nil
        }
        var query = self.table.select(self.table[*])
        query = uid != nil ? query.where(self.accountId == accountId && self.uid != uid) : query.where(self.accountId == accountId && uids.contains(self.uid))
        query = query.order(self.updated.desc, self.id.desc)
        do {
            var users = [UserProto]()
            for r in try db.prepare(query) {
                if let u = rowToUser(r: r) {
                    users.append(u)
                }
            }
            return users
        } catch {
            Cache.log.error("UserDb - read operation failed: error = %{public}@", error.localizedDescription)
        }
        return nil
    }

    // Read users with uids in the array.
    func read(uids: [String]) -> [UserProto]? {
        return read(one: nil, multiple: uids)
    }

    // Select all users except given user.
    func readAll(for uid: String?) -> [UserProto]? {
        return read(one: uid, multiple: [])
    }
}
