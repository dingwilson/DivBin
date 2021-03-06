//
//  VerifyTableViewCell.swift
//  DivBin
//
//  Created by Wilson Ding on 4/23/17.
//  Copyright © 2017 wilsonding. All rights reserved.
//

import UIKit

class VerifyTableViewCell: UITableViewCell {

    @IBOutlet weak var verifyImage: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var timestampLabel: UILabel!
    @IBOutlet weak var upValue: UILabel!
    @IBOutlet weak var downValue: UILabel!
    @IBOutlet weak var downButtonOutlet: UIButton!
    @IBOutlet weak var upButtonOutlet: UIButton!
    
    var imageLink: String!
    
    
}
