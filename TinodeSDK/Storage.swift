//
//  Storage.swift
//  ios
//
//  Copyright © 2019 Tinode. All rights reserved.
//

import Foundation

public protocol Message {
    // Get current message payload.
    var content: Drafty? { get }

    // Timestamp
    var ts: Date? { get }

    // Sender ID
    var from: String? { get }

    // Sync status
    var status: Int? { get }

    // Get current message unique ID (database ID).
    var msgId: Int64 { get }

    // Get Tinode seq Id of the message (different from database ID).
    var seqId: Int { get }

    var isDraft: Bool { get }
    var isReady: Bool { get }
    var isDeleted: Bool { get }
    func isDeleted(hard: Bool) -> Bool
    var isSynced: Bool { get }
    var isPending: Bool { get }
}

extension Message {
    // Can't use Equatable because Swift wants both
    // left and right side be the same *concrete* class,
    // not a protocol.
    public func equals(_ other: Message) -> Bool {
        return
            self.msgId == other.msgId &&
            self.seqId == other.seqId &&
            self.ts == other.ts &&
            self.status == other.status
    }
}

// Base protocol for implementing persistance.
public protocol Storage: class {
    // Min and max values.
    typealias Range = (min: Int, max: Int)

    var myUid: String? { get set }

    var deviceToken: String? { get set }

    func logout()

    // Server time minus local time.
    func setTimeAdjustment(adjustment: TimeInterval)

    var isReady: Bool { get }

    // Fetch all topics.
    func topicGetAll(from tinode: Tinode?) -> [TopicProto]?
    // Add new topic.
    @discardableResult
    func topicAdd(topic: TopicProto) -> Int64
    // Incoming change to topic description:
    // the already mutated topic in memory is synchronized to DB.
    @discardableResult
    func topicUpdate(topic: TopicProto) -> Bool
    // Delete topic.
    @discardableResult
    func topicDelete(topic: TopicProto) -> Bool

    // Get seq IDs of the stored messages as a Range.
    func getCachedMessagesRange(topic: TopicProto) -> Range?
    // Local user reported messages as read.
    @discardableResult
    func setRead(topic: TopicProto, read: Int) -> Bool
    // Local user reported messages as received.
    @discardableResult
    func setRecv(topic: TopicProto, recv: Int) -> Bool

    // Add subscription in a generic topic.
    // The subscription is received from the server.
    @discardableResult
    func subAdd(topic: TopicProto, sub: SubscriptionProto) -> Int64
    // Update subscription in a generic topic.
    @discardableResult
    func subUpdate(topic: TopicProto, sub: SubscriptionProto) -> Bool
    // Add a new subscriber to topic.
    // The new subscriber is being added locally.
    func subNew(topic: TopicProto, sub: SubscriptionProto) -> Int64
    // Delete existing subscription.
    @discardableResult
    func subDelete(topic: TopicProto, sub: SubscriptionProto) -> Bool

    // Get a list o topic subscriptions from DB.
    func getSubscriptions(topic: TopicProto) -> [SubscriptionProto]?

    // Read user description.
    func userGet(uid: String) -> UserProto?
    // Insert new user.
    func userAdd(user: UserProto) -> Int64
    // Update existing user.
    @discardableResult
    func userUpdate(user: UserProto) -> Bool

    // Message received from the server.
    func msgReceived(topic: TopicProto, sub: SubscriptionProto?, msg: MsgServerData?) -> Int64

    // Save message to DB as queued or synced.
    // Params:
    //   topic: topic which sent the message.
    //   data: message data to save.
    // Returns:
    //   database ID of the message suitable for use in.
    func msgSend(topic: TopicProto, data: Drafty) -> Int64

    // Save message to database as a draft.
    // Draft will not be sent to server until it status changes.
    // Params:
    //   topic: topic which sent the message.
    //   data: message data to save.
    // Returns:
    //   database ID of the message suitable for use in
    func msgDraft(topic: TopicProto, data: Drafty) -> Int64

    // Update message draft content without
    // Params:
    //   topic: topic which sent the message.
    //   dbMessageId: database ID of the message.
    //   data: updated content of the message. Must not be null.
    // Returns true on success, false otherwise.
    func msgDraftUpdate(topic: TopicProto, dbMessageId: Int64, data: Drafty) -> Bool

    // Message is ready to be sent to the server.
    // Params:
    //   topic: topic which sent the message
    //   dbMessageId: database ID of the message.
    //   data: updated content of the message. If null only status is updated.
    // Returns true on success, false otherwise.
    func msgReady(topic: TopicProto, dbMessageId: Int64, data: Drafty) -> Bool

    // Message is being sent to the server.
    // Params
    //   topic: topic which sent the message
    //   dbMessageId: database ID of the message.
    //   sync: true when the sync started, false when it's finished unsuccessfully.
    // Returns true on success, false otherwise.
    @discardableResult
    func msgSyncing(topic: TopicProto, dbMessageId: Int64, sync: Bool) -> Bool

    // Deletes a message by database id.
    func msgDiscard(topic: TopicProto, dbMessageId: Int64) -> Bool

    // Message delivered to the server and received a real seq ID.
    // Params:
    //   topic: topic which sent the message.
    //   dbMessageId: database ID of the message.
    //   timestamp: server timestamp.
    //   seq: server-issued message seqId.
    // Returns true on success, false otherwise.
    func msgDelivered(topic: TopicProto, dbMessageId: Int64,
                      timestamp: Date, seq: Int) -> Bool
    // Mark messages for deletion by range.
    @discardableResult
    func msgMarkToDelete(topic: TopicProto,
                         from idLo: Int, to idHi: Int, markAsHard: Bool) -> Bool
    // Mark messages for deletion by seq ID list.
    func msgMarkToDelete(topic: TopicProto, list: [Int], markAsHard: Bool) -> Bool
    // Delete messages.
    @discardableResult
    func msgDelete(topic: TopicProto, delete id: Int,
                   deleteFrom idLo: Int, deleteTo idHi: Int) -> Bool
    // Delete messages.
    func msgDelete(topic: TopicProto, delete id: Int, deleteAll list: [Int]?) -> Bool
    // Set recv value for a given subscriber.
    @discardableResult
    func msgRecvByRemote(sub: SubscriptionProto, recv: Int?) -> Bool
    // Set read value for a given subscriber.
    @discardableResult
    func msgReadByRemote(sub: SubscriptionProto, read: Int?) -> Bool

    // Retrieves a single message by database id.
    func getMessageById(topic: TopicProto, dbMessageId: Int64) -> Message?

    // Returns a list of unsent messages.
    func getQueuedMessages(topic: TopicProto) -> [Message]?

    // Returns a list of pending delete message seq ids.
    // topic: topic where the messages were deleted.
    // hard: when true, fetch hard-deleted messages, soft-deleted otherwise.
    func getQueuedMessageDeletes(topic: TopicProto, hard: Bool) -> [Int]?
}
