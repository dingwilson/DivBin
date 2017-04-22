//
//  SelectionViewController.swift
//  DivBin
//
//  Created by Wilson Ding on 4/22/17.
//  Copyright © 2017 wilsonding. All rights reserved.
//

import UIKit

class SelectionViewController: UIViewController {
    
    var currentImage: UIImage?
    var tag: String?
    
    override var prefersStatusBarHidden : Bool {
        return true
    }
    
    @IBOutlet weak var titleLabel: UILabel!
    
    @IBOutlet weak var imageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        imageView?.image = currentImage
        titleLabel.text = tag
    }
    
    @IBAction func didPressCompost(_ sender: Any) {
        print("Compost")
        self.performSegue(withIdentifier: "unwindSegue", sender: self)
    }
    
    @IBAction func didPressTrash(_ sender: Any) {
        print("Trash")
        self.performSegue(withIdentifier: "unwindSegue", sender: self)
    }
    
    @IBAction func didPressRecycle(_ sender: Any) {
        print("Recycle")
        self.performSegue(withIdentifier: "unwindSegue", sender: self)
    }
    
    @IBAction func didPressDonate(_ sender: Any) {
        print("Donate")
        self.performSegue(withIdentifier: "unwindSegue", sender: self)
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
