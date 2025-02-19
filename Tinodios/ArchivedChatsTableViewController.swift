//
//  ArchivedChatsTableViewController.swift
//  Tinodios
//
//  Copyright © 2019 Tinode. All rights reserved.
//

import UIKit
import TinodeSDK

class ArchivedChatsTableViewController: UITableViewController {

    @IBOutlet var chatListTableView: UITableView!
    private var topics: [DefaultComTopic] = []
    override func viewDidLoad() {
        super.viewDidLoad()
        self.chatListTableView.register(UINib(nibName: "ChatListViewCell", bundle: nil), forCellReuseIdentifier: "ChatListViewCell")
        self.reloadData()
    }

    private func reloadData() {
        self.topics = Cache.getTinode().getFilteredTopics(filter: {(topic: TopicProto) in
            return topic.topicType.matches(TopicType.user) && topic.isArchived
        })?.map {
            // Must succeed.
            $0 as! DefaultComTopic
        } ?? []
    }
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.topics.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ChatListViewCell") as! ChatListViewCell

        let topic = self.topics[indexPath.row]
        //cell.textLabel?.text = topic.pub?.fn ?? "Unknown"
        cell.fillFromTopic(topic: topic)
        return cell
    }
    private func unarchiveTopic(topic: DefaultComTopic) {
        do {
            try topic.updateArchived(archived: false)?.then(
                onSuccess: { [weak self] msg in
                    DispatchQueue.main.async {
                        if let vc = self {
                            vc.reloadData()
                            vc.tableView.reloadData()
                            // If there are no more archived topics, close the view.
                            if vc.topics.isEmpty {
                                vc.navigationController?.popViewController(animated: true)
                                vc.dismiss(animated: true, completion: nil)
                            }
                        }
                    }
                    return nil
                },
                onFailure: UiUtils.ToastFailureHandler)
        } catch {
            UiUtils.showToast(message: "Failed to unarchive topic: \(error)")
        }
    }
    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let unarchive = UITableViewRowAction(style: .normal, title: "Unarchive") { (action, indexPath) in
            let topic = self.topics[indexPath.row]
            self.unarchiveTopic(topic: topic)
        }

        return [unarchive]
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated:  true)
        self.performSegue(withIdentifier: "ArchivedChats2Messages",
                          sender: self.topics[indexPath.row].name)
    }

    // MARK: - Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ArchivedChats2Messages", let topicName = sender as? String {
            let messageController = segue.destination as! MessageViewController
            messageController.topicName = topicName
        }
    }
}
