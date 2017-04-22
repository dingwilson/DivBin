//
//  SelectionRootViewController.swift
//  DivBin
//
//  Created by Wilson Ding on 4/22/17.
//  Copyright © 2017 wilsonding. All rights reserved.
//

import UIKit

class SelectionRootViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    override var prefersStatusBarHidden : Bool {
        return true
    }
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var tableView: UITableView!
    
    var currentImage: UIImage?
    var tags: [Any]?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delegate = self
        tableView.dataSource = self
        
        imageView.image = currentImage
        
        print(tags)

        // Do any additional setup after loading the view.
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return (tags?.count)!
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        
        if let stringTag = tags {
            cell.textLabel?.text = stringTag[indexPath.row] as? String
        }
        
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.performSegue(withIdentifier: "goToChoose", sender: self)
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
