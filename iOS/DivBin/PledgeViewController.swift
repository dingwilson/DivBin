//
//  PledgeViewController.swift
//  DivBin
//
//  Created by Wilson Ding on 4/23/17.
//  Copyright © 2017 wilsonding. All rights reserved.
//

import UIKit
import ImagePicker
import FirebaseStorage
import FirebaseDatabase
import FirebaseAuth

class PledgeViewController: UIViewController {
    
    var storageRef: FIRStorageReference!
    var databaseRef: FIRDatabaseReference!
    
    @IBOutlet weak var imageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        storageRef = FIRStorage.storage().reference()
        databaseRef = FIRDatabase.database().reference()
        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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
            "Down": 0
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
