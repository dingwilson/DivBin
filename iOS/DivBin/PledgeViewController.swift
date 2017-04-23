//
//  PledgeViewController.swift
//  DivBin
//
//  Created by Wilson Ding on 4/23/17.
//  Copyright © 2017 wilsonding. All rights reserved.
//

import UIKit
import ImagePicker

class PledgeViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

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
        imagePicker.dismiss(animated: true, completion: nil)
    }
    
    func cancelButtonDidPress(_ imagePicker: ImagePickerController) {
        // no image selected
    }
}
