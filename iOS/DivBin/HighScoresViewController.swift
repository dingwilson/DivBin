//
//  HighScoresViewController.swift
//  DivBin
//
//  Created by Wilson Ding on 4/23/17.
//  Copyright © 2017 wilsonding. All rights reserved.
//

import UIKit
import FirebaseDatabase

class HighScoresViewController: UIViewController {
    
    private var itemsRef: FIRDatabaseHandle?
    var databaseRef: FIRDatabaseReference!
    var scores: Dictionary<String, Int> = [:]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        databaseRef = FIRDatabase.database().reference()
        setupTopScores()
        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func setupTopScores() {
        
        databaseRef?.child("Users/").observe(.childAdded, with: { (snapshot) -> Void in
        
            guard let user = snapshot.value as? NSDictionary else {
                return
            }
            
            let username = user["Username"] as! String
            let score = user["Score"] as! Int
            
            self.scores[username] = score
            
        })
        
        databaseRef?.child("Users/").observe(.value, with: { (snapshot) -> Void in
            
            var data = [String: Int]()
            
            let values = snapshot.value as! NSDictionary
            
            let keys = values.allKeys
            
            for key in keys {
                
                let val = values[key] as! NSDictionary
                let valScore = val["Score"] as! Int
                let valKey = key as! String
                data[valKey] = valScore
                
            }
            
            let sorted = data.sorted(by: {
                let obj1 = data[$0.key]
                let obj2 = data[$1.key]
                if (obj1! - obj2! > 0) {
                    return true
                }
                return false
            })
            
            print(sorted)
            // Assign labels here.
        })
    
    }
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
