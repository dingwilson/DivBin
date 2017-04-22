//
//  SelectionRootViewController.swift
//  DivBin
//
//  Created by Wilson Ding on 4/22/17.
//  Copyright © 2017 wilsonding. All rights reserved.
//

import UIKit

class SelectionRootViewController: UIViewController {
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var tableView: UITableView!
    
    
    var currentImage: UIImage?
    var tags: [Any]?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        imageView.image = currentImage
        
        print(tags)

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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