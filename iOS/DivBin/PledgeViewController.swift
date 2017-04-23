//
//  PledgeViewController.swift
//  DivBin
//
//  Created by Wilson Ding on 4/23/17.
//  Copyright © 2017 wilsonding. All rights reserved.
//

import UIKit
import SwiftVideoBackground
import ImagePicker
import FirebaseStorage
import FirebaseDatabase
import FirebaseAuth

class PledgeViewController: UIViewController {
    
    var storageRef: FIRStorageReference!
    var databaseRef: FIRDatabaseReference!
    
    @IBOutlet weak var backgroundVideo: BackgroundVideo!
    
    @IBOutlet weak var numberOfPledges: UILabel!
    @IBOutlet weak var remainingPledges: UILabel!
    
    var numberPledges = 0
    private var itemsRef: FIRDatabaseHandle?

    
    override func viewDidLoad() {
        super.viewDidLoad()
        storageRef = FIRStorage.storage().reference()
        databaseRef = FIRDatabase.database().reference()
        
        backgroundVideo.createBackgroundVideo(name: "Flying-Birds", type: "mp4")
        
        grabFromFB()
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
        super.viewWillAppear(animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        self.navigationController?.setNavigationBarHidden(false, animated: animated)
        super.viewWillDisappear(animated)
    }
    
    @IBAction func didPressPhotoButton(_ sender: Any) {
        var configuration = Configuration()
        configuration.doneButtonTitle = "Verify"
        configuration.noImagesTitle = "Sorry! There are no images available."
        configuration.recordLocation = false
        
        let imagePicker = ImagePickerController(configuration: configuration)
        imagePicker.imageLimit = 1
        imagePicker.delegate = self
        present(imagePicker, animated: true, completion: nil)
    }
    
    func grabFromFB(){
        
        let useruid = FIRAuth.auth()!.currentUser!.uid

        databaseRef.child("Users/\(useruid)/Pledges").observeSingleEvent(of: .value, with: { (snapshot) in
            guard let pledges = snapshot.value as? Int else {
                return
            }
            
            self.numberPledges = pledges
            self.numberOfPledges.text = "\(self.numberPledges)"
        })
        
        itemsRef = databaseRef.child("Users/\(useruid)/PledgesLeft").observe(.value, with: { (snapshot) -> Void in
            
            let value = snapshot.value as? Int
            self.remainingPledges.text = "I still have \(value!) times to go."
        })

    }
    
    @IBAction func didPressShipping(_ sender: Any) {
        let url = URL(string: "http://sample-env-1.6xphxzzcm4.us-east-1.elasticbeanstalk.com/labels/Kevin%20Nguyen/1234%20Fake%20Street/Fake%20City/TX/44023")
        UIApplication.shared.open(url!, options: [:], completionHandler: nil)
    }
    
}

extension PledgeViewController: ImagePickerDelegate {
    func wrapperDidPress(_ imagePicker: ImagePickerController, images: [UIImage]) {
        // not sure what to do here
    }
    
    func doneButtonDidPress(_ imagePicker: ImagePickerController, images: [UIImage]) {
        // upload UIImage to Firebase for checking
        upload(image: images[0])
        imagePicker.dismiss(animated: true, completion: nil)
        
    }
    
    func cancelButtonDidPress(_ imagePicker: ImagePickerController) {
        // no image selected
    }
    
    func upload(image: UIImage) {
        let key = databaseRef.child("Timeline").childByAutoId().key
        let useruid = FIRAuth.auth()!.currentUser!.uid
        
        let metad = [
            "User":useruid,
            "Up":0,
            "Down": 0,
            "Timestamp" : "\(Date())"
        ] as [String : Any]
        
        databaseRef.child("Timeline").child(key).setValue(metad)
        
        let data = UIImageJPEGRepresentation(image, 0.5)
        
        let uploadRef = storageRef.child(key)
        
        let uploadTask = uploadRef.put(data!, metadata:nil) { (metadata, error) in
            guard let metadata = metadata else {
                // Uh-oh, an error occurred!
                return
            }
            // Metadata contains file metadata such as size, content-type, and download URL.
            let downloadURL = metadata.downloadURL
        }
    }
}
