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
import FirebaseAuth

class VerifyTableViewController: UITableViewController {

    var storageRef: FIRStorageReference!
    var databaseRef: FIRDatabaseReference!
    private var itemsRef: FIRDatabaseHandle?
    var timelineData = [Dictionary<String, Any>]()
    
    let profileData = {}
//        "1Mmf9P7QfkWTkYpzHSCQXoeD6Om1": "VongolaXSky",
//        "FPhncEamMnXYdj1POLkIMmpMSv92": "Shodai",
//        "S6mKQORKoKXImA5hreZHxoia99s1": "Shodai"
//    ]
//    
    
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

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

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
                if let error = error {
                    // Uh-oh, an error occurred!
                } else {
                    // Data for "images/island.jpg" is returned
                    cell.imageLink = self.timelineData[indexPath.row]["ID"] as! String
                    let image = UIImage(data: data!)
                    cell.verifyImage.image = image
                }
            }
        
            cell.timestampLabel.text = timelineData[indexPath.row]["Timestamp"] as! String
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

    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */
    
    func download(data: String) {
        let islandRef = storageRef.child(data)
        
        // Download in memory with a maximum allowed size of 1MB (1 * 1024 * 1024 bytes)
        islandRef.data(withMaxSize: 1 * 1024 * 1024) { data, error in
            if let error = error {
                // Uh-oh, an error occurred!
            } else {
                // Data for "images/island.jpg" is returned
                let image = UIImage(data: data!)
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
        
        incrementScore()
        
    }
    
    func decrementSubmission(photoID: String) {
        databaseRef.child("Timeline/\(photoID)/Down").observeSingleEvent(of: .value, with: { (snapshot) in
            guard var Down = snapshot.value as? Int else {
                return
            }
            
            Down-=1
            
            self.databaseRef.child("Timeline/\(photoID)/Down").setValue(Down)
        })
        
        incrementScore()
        
    }
    
    func incrementScore() {
        
        let useruid = FIRAuth.auth()!.currentUser!.uid
        
        databaseRef.child("Users/\(useruid)/Score").observeSingleEvent(of: .value, with: { (snapshot) in
            guard var Score = snapshot.value as? Int else {
                return
            }
            
            Score+=1
            
            self.databaseRef.child("Users/\(useruid)/Score").setValue(Score)
        })
        
        
    }
}
