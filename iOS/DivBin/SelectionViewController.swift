//
//  SelectionViewController.swift
//  DivBin
//
//  Created by Wilson Ding on 4/22/17.
//  Copyright © 2017 wilsonding. All rights reserved.
//

import UIKit
import Alamofire
import FirebaseDatabase

class SelectionViewController: UIViewController {
    
    var currentImage: UIImage?
    var tag: String?
    
    var server: String?
    var ref: FIRDatabaseReference?
    
    override var prefersStatusBarHidden : Bool {
        return true
    }
    
    @IBOutlet weak var titleLabel: UILabel!
    
    @IBOutlet weak var imageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        imageView?.image = currentImage
        titleLabel.text = tag
        ref = FIRDatabase.database().reference()
    
    }
    
    @IBAction func didPressCompost(_ sender: Any) {
        sendData(type: "compost")
        self.performSegue(withIdentifier: "unwindSegue", sender: self)
    }
    
    @IBAction func didPressTrash(_ sender: Any) {
        sendData(type: "trash")
        self.performSegue(withIdentifier: "unwindSegue", sender: self)
    }
    
    @IBAction func didPressRecycle(_ sender: Any) {
        sendData(type: "recycle")
        self.performSegue(withIdentifier: "unwindSegue", sender: self)
    }
    
    @IBAction func didPressDonate(_ sender: Any) {
        sendData(type: "donate")
        self.performSegue(withIdentifier: "unwindSegue", sender: self)
    }
    
    func sendData(type: String) {
        
        self.ref?.child(tag!).setValue(type)

    }

}
