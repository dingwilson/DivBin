//
//  VerifyTableViewController.swift
//  DivBin
//
//  Created by Wilson Ding on 4/23/17.
//  Copyright © 2017 wilsonding. All rights reserved.
//

import UIKit
import FirebaseDatabase
import FirebaseStorage

class VerifyTableViewController: UITableViewController {

    var storageRef: FIRStorageReference!
    var databaseRef: FIRDatabaseReference!
    private var itemsRef: FIRDatabaseHandle?
    var timelineData = [Dictionary<String, Any>]()
    
    let profileData = {}
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        storageRef = FIRStorage.storage().reference()
        databaseRef = FIRDatabase.database().reference()
        
        databaseRef = FIRDatabase.database().reference()
        
        itemsRef = databaseRef?.child("Timeline").observe(.childAdded, with: { (snapshot) -> Void in
            
            let value = snapshot.value as? NSDictionary
            
            let imageID = snapshot.key
            let numDown = value?["Down"] as? Int
            let numUp = value?["Up"] as? Int
            let userID = value?["User"] as? String
            let timestamp = value?["Timestamp"] as? String
            
            var timelineElem = [String: Any]()
            timelineElem["ID"] = imageID
            timelineElem["Up"] = numUp
            timelineElem["Down"] = numDown
            timelineElem["User"] = userID
            timelineElem["Timestamp"] = timestamp
            
            self.timelineData.append(timelineElem)
            self.tableView.reloadData()
        })
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return timelineData.count
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! VerifyTableViewCell
        
            let desiredUID = timelineData[indexPath.row]["User"] as! String
            databaseRef.child("Users/\(desiredUID)/Username").observeSingleEvent(of: .value, with: { (snapshot) in
                guard let Username = snapshot.value as? String else {
                    return
                }
                cell.nameLabel.text = Username
            })
        
            let islandRef = storageRef.child(timelineData[indexPath.row]["ID"] as! String)
            
            // Download in memory with a maximum allowed size of 1MB (1 * 1024 * 1024 bytes)
            islandRef.data(withMaxSize: 1 * 1024 * 1024) { data, error in
                if error != nil {
                    // Uh-oh, an error occurred!
                } else {
                    // Data for "images/island.jpg" is returned
                    cell.imageLink = self.timelineData[indexPath.row]["ID"] as! String
                    let image = UIImage(data: data!)
                    cell.verifyImage.image = image
                }
            }
        
            cell.timestampLabel.text = timelineData[indexPath.row]["Timestamp"] as? String
//            messageCell.sendButtonOutlet.addTarget(self, action: #selector(ChatListTableViewController.sendButtonAction(_:)), for: UIControlEvents.touchUpInside)
            cell.downButtonOutlet.tag = indexPath.row
            cell.downButtonOutlet.addTarget(self, action: #selector(VerifyTableViewController.downButtonAction(_:)), for: UIControlEvents.touchUpInside)
            cell.upButtonOutlet.tag = indexPath.row
            cell.upButtonOutlet.addTarget(self, action: #selector(VerifyTableViewController.upButtonAction(_:)), for: UIControlEvents.touchUpInside)
        
        let values: String = "Timeline/\(timelineData[indexPath.row]["ID"] as! String)"
        
            databaseRef.child(values).observe(.value, with: { (snapshot) -> Void in
                let values = snapshot.value as! NSDictionary
                
                cell.downValue.text = "\(values["Down"] as! Int)"
                cell.upValue.text = "\(values["Up"] as! Int)"
                
            })
        
        return cell
    }
    
    func downButtonAction(_ sender:UIButton!){
        let photoID = self.timelineData[sender.tag]["ID"] as? String
        decrementSubmission(photoID: photoID!)
        
        let cell = self.tableView.cellForRow(at: IndexPath(row: sender.tag, section: 0)) as! VerifyTableViewCell
        cell.downButtonOutlet.isEnabled = false
        cell.upButtonOutlet.isEnabled = false
    }
    
    func upButtonAction(_ sender:UIButton!){
        let photoID = self.timelineData[sender.tag]["ID"] as? String
        incrementSubmission(photoID: photoID!)
        let cell = self.tableView.cellForRow(at: IndexPath(row: sender.tag, section: 0)) as! VerifyTableViewCell
        cell.downButtonOutlet.isEnabled = false
        cell.upButtonOutlet.isEnabled = false
    }
    
    func download(data: String) {
        let islandRef = storageRef.child(data)
        
        // Download in memory with a maximum allowed size of 1MB (1 * 1024 * 1024 bytes)
        islandRef.data(withMaxSize: 1 * 1024 * 1024) { data, error in
            if error != nil {
                // Uh-oh, an error occurred!
            } else {
                // Data for "images/island.jpg" is returned
                _ = UIImage(data: data!)
            }
        }
        
    }
    
    func incrementSubmission(photoID: String) {
        databaseRef.child("Timeline/\(photoID)/Up").observeSingleEvent(of: .value, with: { (snapshot) in
            guard var Up = snapshot.value as? Int else {
                return
            }
            
            Up+=1;
            
            self.databaseRef.child("Timeline/\(photoID)/Up").setValue(Up)
        })
        
    }
    
    func decrementSubmission(photoID: String) {
        databaseRef.child("Timeline/\(photoID)/Down").observeSingleEvent(of: .value, with: { (snapshot) in
            guard var Down = snapshot.value as? Int else {
                return
            }
            
            Down-=1
            
            self.databaseRef.child("Timeline/\(photoID)/Down").setValue(Down)
        })
        
    }
}
