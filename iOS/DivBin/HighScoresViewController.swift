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
    
    @IBOutlet weak var firstName: UILabel!
    @IBOutlet weak var firstScore: UILabel!
    
    @IBOutlet weak var secondName: UILabel!
    @IBOutlet weak var secondScore: UILabel!
    
    @IBOutlet weak var thirdName: UILabel!
    @IBOutlet weak var thirdScore: UILabel!
    
    private var itemsRef: FIRDatabaseHandle?
    var databaseRef: FIRDatabaseReference!
    var scores: Dictionary<String, Int> = [:]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        databaseRef = FIRDatabase.database().reference()
        setupTopScores()
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
                let valKey = val["Username"] as! String
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
            
            self.firstName.text = sorted[0].key
            self.firstScore.text = "\(sorted[0].value)"
            self.secondName.text = sorted[1].key
            self.secondScore.text = "\(sorted[1].value)"
            self.thirdName.text = sorted[2].key
            self.thirdScore.text = "\(sorted[2].value)"
        })
    }
}
