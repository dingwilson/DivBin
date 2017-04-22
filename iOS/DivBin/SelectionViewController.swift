//
//  SelectionViewController.swift
//  DivBin
//
//  Created by Wilson Ding on 4/22/17.
//  Copyright © 2017 wilsonding. All rights reserved.
//

import UIKit
import Alamofire

class SelectionViewController: UIViewController {
    
    var currentImage: UIImage?
    var tag: String?
    
    var server: String?
    
    override var prefersStatusBarHidden : Bool {
        return true
    }
    
    @IBOutlet weak var titleLabel: UILabel!
    
    @IBOutlet weak var imageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        imageView?.image = currentImage
        titleLabel.text = tag
        
        loadServerURL()
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
        let url = "\(self.server!)/lists/\(type)/\(tag!)"
        
        Alamofire.request(url, method: .get).validate().responseJSON { response in
            switch response.result {
            case .success(let _): break
                // Yay
            case .failure(let error):
                print(error)
            }
        }
    }
    
    func loadServerURL() {
        if let url = Bundle.main.url(forResource:"Keys", withExtension: "plist"),
            let keys = NSDictionary(contentsOf: url) as? [String:Any] {
            
            if let serverURL = keys["Server_URL"] as? String {
                server = serverURL
            } else {
                fatalError("Unable to find Server URL")
            }
        } else {
            fatalError("Error: Could not find Keys.plist")
        }
    }

}
