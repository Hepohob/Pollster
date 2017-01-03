//
//  AllQandAsTableViewController.swift
//  Pollster
//
//  Created by Aleksei Neronov on 03.01.17.
//  Copyright © 2017 Aleksei Neronov. All rights reserved.
//

import UIKit
import CloudKit

class AllQandAsTableViewController: UITableViewController {

    // MARK: Model
    
    var allQandAs = [CKRecord]() {
        didSet {
            tableView.reloadData()
        }
    }

    // MARK: View Controller Lifecycle

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        fetchAllQandAs()
        iCloudSubscribeToQandA()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        iCloudUnsubscribeToQandA()
    }
    
    // MARK: Private Implementation

    private let database = CKContainer.default().publicCloudDatabase

    private func fetchAllQandAs() {
        let predicate = NSPredicate(format: "TRUEPREDICATE")
        let query = CKQuery(recordType: Cloud.Entity.QandA, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key:Cloud.Attribute.Question, ascending:true)]
        database.perform(query, inZoneWith: nil) { (records, error) in
            if records != nil {
                DispatchQueue.main.async {
                    self.allQandAs = records!
                }
            }
        }
    }
    
    //MAR: Subscriptions
    
    private var subscriptionID = "All QandA Creations and Deletions"
    private var cloudKitObserver: NSObjectProtocol?
    
    
    private func iCloudSubscribeToQandA() {
        let predicate = NSPredicate(format: "TRUEPREDICATE")
        let subsciptions = CKQuerySubscription(recordType: Cloud.Entity.QandA,
                                               predicate: predicate,
                                               subscriptionID: self.subscriptionID,
                                               options: [.firesOnRecordCreation, .firesOnRecordDeletion])
        // some subscription notification info....
        database.save(subsciptions) { (savedSubscription, error) in
            if (error as? NSError)?.code == CKError.serverRejectedRequest.rawValue {
                // ignore, already have subscription...
            } else if error != nil {
                // report, because something happens
            }
        }
        //observing notification from iCloud
        cloudKitObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name(rawValue: CloudKitNotifications.NotificationReceived),
            object: nil,
            queue: OperationQueue.main,
            using: { notification in
                if let ckqn = (notification as NSNotification).userInfo?[CloudKitNotifications.NotificationKey] as? CKQueryNotification {
                    self.iCloudHandleSubscriptionNotification(ckqn)
                }
        }
        )
    }
    
    private func iCloudHandleSubscriptionNotification(_ ckqn: CKQueryNotification)
    {
        if ckqn.subscriptionID == self.subscriptionID {
            if let recordID = ckqn.recordID {
                switch ckqn.queryNotificationReason {
                case .recordCreated:
                    database.fetch(withRecordID: recordID) { (record, error) in
                        if record != nil {
                            DispatchQueue.main.async {
                                self.allQandAs = (self.allQandAs + [record!]).sorted {
                                    return $0.question < $1.question
                                }
                            }
                        }
                    }
                    
                case .recordDeleted:
                    DispatchQueue.main.async {
                        self.allQandAs = self.allQandAs.filter { $0.recordID != recordID }
                    }
                default:
                    break
                }
            }
        }
    }
    
    private func iCloudUnsubscribeToQandA() {
        database.delete(withSubscriptionID: self.subscriptionID) { (subscription, error) in
            // handle errors and other...
        }
    }
    
    //MARK: Table delegates
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return allQandAs.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "QandA Cell", for: indexPath)
        cell.textLabel?.text = allQandAs[indexPath.row].question
        return cell
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return allQandAs[indexPath.row].wasCreatedByThisUser
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let record = allQandAs[indexPath.row]
            database.delete(withRecordID: record.recordID) { (deletedRecord, error) in
                // handle errors
            }
            allQandAs.remove(at: indexPath.row)
        }
    }
    
    // MARK: Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "Show QandA" {
            if let ckQandATVC = segue.destination as? CloudQandATableViewController {
                if let cell = sender as? UITableViewCell, let indexPath = tableView.indexPath(for: cell) {
                    ckQandATVC.ckQandARecord = allQandAs[indexPath.row]
                } else {
                    ckQandATVC.ckQandARecord = CKRecord(recordType: Cloud.Entity.QandA)
                }
            }
        }
    }

}
