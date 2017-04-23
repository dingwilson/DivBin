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
    var timelineData = [String: Any]()
    
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
            
            self.timelineData[snapshot.key] = snapshot.value
        
        })
        
//        profileData["1Mmf9P7QfkWTkYpzHSCQXoeD6Om1"] = "VongolaXSky";
//        profileData["FPhncEamMnXYdj1POLkIMmpMSv92"] = "Shodai100";
//        profileData["FPhncEamMnXYdj1POLkIMmpMSv92"] = "Shodai100";

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 0
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return timelineData.count
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "reuseIdentifier", for: indexPath)

//         cell.textLabel?.text = self.timelineData[ indexPath ]
        return cell
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
    
}
