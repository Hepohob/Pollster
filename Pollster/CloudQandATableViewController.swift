//
//  CloudQandATableViewController.swift
//  Pollster
//
//  Created by Aleksei Neronov on 02.01.17.
//  Copyright © 2017 Aleksei Neronov. All rights reserved.
//

import UIKit
import CloudKit

class CloudQandATableViewController: QandATableViewController {
    
    var ckQandARecord: CKRecord {
        get {
            if _ckQandARecord == nil {
                _ckQandARecord = CKRecord(recordType: Cloud.Entity.QandA)
            }
            return _ckQandARecord!
        }
        set {
            _ckQandARecord = newValue
        }
    }
    
    private var _ckQandARecord: CKRecord? {
        didSet {
            let question = ckQandARecord[Cloud.Attribute.Question] as? String ?? ""
            let answers = ckQandARecord[Cloud.Attribute.Answers] as? [String] ?? []
            qanda = QandA(question: question, answers: answers)
            asking = ckQandARecord.wasCreatedByThisUser
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    //MARK: iCloud Kit workflow
    
    private let database = CKContainer.default().publicCloudDatabase
    
    @objc private func iCloudUpdate() {
        if !qanda.answers.isEmpty && !qanda.question.isEmpty {
            ckQandARecord[Cloud.Attribute.Question] = qanda.question as CKRecordValue?
            ckQandARecord[Cloud.Attribute.Answers] = qanda.answers as CKRecordValue?
            iCloudSaveRecord(recordToSave: ckQandARecord)
        }
    }
    
    private func iCloudSaveRecord(recordToSave: CKRecord) {
        database.save(recordToSave, completionHandler: { (savedRecord, error) in
            if (error as? NSError)?.code == CKError.serverRecordChanged.rawValue {
                // record too old for recording, present newer record
            } else if error != nil {
                self.retryAfterError(error: error as NSError?, with: #selector(self.iCloudUpdate))
            }
        })
    }
    
    private func retryAfterError(error:NSError?, with selector:Selector) {
        if let retryInterval = error?.userInfo[CKErrorRetryAfterKey] as? TimeInterval {
            DispatchQueue.main.async {
                Timer.scheduledTimer(timeInterval: retryInterval,
                                     target: self,
                                     selector: selector,
                                     userInfo: nil,
                                     repeats: false)
            }
        }
    }
    
    override func textViewDidEndEditing(_ textView: UITextView) {
        super.textViewDidEndEditing(textView)
        iCloudUpdate()
    }
    
}
