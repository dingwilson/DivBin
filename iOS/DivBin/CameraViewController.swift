//
//  CameraViewController.swift
//  DivBin
//
//  Created by Wilson Ding on 4/21/17.
//  Copyright © 2017 wilsonding. All rights reserved.
//

import UIKit
import AVFoundation
import Clarifai

class CameraViewController: UIViewController {
    
    @IBOutlet weak var previewView: UIView!
    
    var captureSession: AVCaptureSession?
    var stillPhotoOutput: AVCapturePhotoOutput?
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    var app: ClarifaiApp?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        loadClarifaiKeys()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
    }
    
    func loadClarifaiKeys() {
        if let url = Bundle.main.url(forResource:"Keys", withExtension: "plist"),
            let keys = NSDictionary(contentsOf: url) as? [String:Any] {
            
            if let clarifaiClientID = keys["Clarifai_Client_ID"] as? String {
                if let clarifaiClientSecret = keys["Clarifai_Client_Secret"] as? String {
                    app = ClarifaiApp(appID: clarifaiClientID, appSecret: clarifaiClientSecret)
                } else {
                    print("Error: Clarifai_Client_Secret not found in Keys.plist")
                }
            } else {
                print("Error: Clarifai_Client_ID not found in Keys.plist")
            }
        } else {
            print("Error: Could not find Keys.plist")
        }
    }
}
