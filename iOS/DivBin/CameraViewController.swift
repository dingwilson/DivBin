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
import Alamofire
import SwiftyJSON

class CameraViewController: UIViewController, AVCapturePhotoCaptureDelegate {
    
    @IBOutlet weak var previewView: UIView!
    
    let cameraTimerInterval: TimeInterval = 3
    
    let blacklistWords: [String] = ["adult", "building", "business", "connection", "education", "exhibition", "indoors", "industry", "internet", "light", "modern", "museum", "music", "no person", "office", "one", "people", "performance", "recreation", "room"]
    
    var captureSession: AVCaptureSession?
    var cameraOutput: AVCapturePhotoOutput?
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    var app: ClarifaiApp?
    var server: String?
    
    var checkTimer: Timer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        loadClarifaiKeys()
        loadServerURL()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        loadCamera()
        
        self.checkTimer = Timer.scheduledTimer(timeInterval: cameraTimerInterval, target: self, selector: #selector(self.takePhoto), userInfo: nil, repeats: true)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureSession!.stopRunning()
        self.checkTimer.invalidate()
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
    
    func loadCamera() {
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = AVCaptureSessionPresetPhoto
        cameraOutput = AVCapturePhotoOutput()
        
        let device = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
        
        if let input = try? AVCaptureDeviceInput(device: device) {
            if (captureSession?.canAddInput(input))! {
                captureSession?.addInput(input)
                if (captureSession?.canAddOutput(cameraOutput))! {
                    captureSession?.addOutput(cameraOutput)
                    previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
                    previewLayer?.videoGravity = AVLayerVideoGravityResizeAspectFill
                    previewLayer?.frame = previewView.bounds
                    previewView.layer.addSublayer(previewLayer!)
                    captureSession?.startRunning()
                }
            } else {
                print("Error: Cannot add input to captureSession")
            }
        } else {
            print("Error: Cannot setup input for captureSession")
        }
    }
    
    func takePhoto() {
        let settings = AVCapturePhotoSettings()
        let previewPixelType = settings.availablePreviewPhotoPixelFormatTypes.first!
        let previewFormat = [
            kCVPixelBufferPixelFormatTypeKey as String: previewPixelType,
            kCVPixelBufferWidthKey as String: 160,
            kCVPixelBufferHeightKey as String: 160
        ]
        settings.previewPhotoFormat = previewFormat
        cameraOutput?.capturePhoto(with: settings, delegate: self as AVCapturePhotoCaptureDelegate)
    }
    
    func capture(_ captureOutput: AVCapturePhotoOutput, didFinishProcessingPhotoSampleBuffer photoSampleBuffer: CMSampleBuffer?, previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {
        
        if let error = error {
            print("Error: \(error.localizedDescription)")
        }
        
        if  let sampleBuffer = photoSampleBuffer,
            let previewBuffer = previewPhotoSampleBuffer,
            let dataImage =  AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer:  sampleBuffer, previewPhotoSampleBuffer: previewBuffer) {

            let dataProvider = CGDataProvider(data: dataImage as CFData)
            let cgImageRef: CGImage! = CGImage(jpegDataProviderSource: dataProvider!, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
            let image = UIImage(cgImage: cgImageRef, scale: 1.0, orientation: UIImageOrientation.right)
            
            let processQueue = DispatchQueue(label: "com.wilsonding.DivBin")
            
            processQueue.async {
                self.processImage(image: image)
            }
        } else {
            print("Encountered error with capturing image")
        }
    }
    
    func processImage(image: UIImage) {
        app?.getModelByName("general-v1.3", completion: { (model, error) in
            let clarifaiImage = ClarifaiImage(image: image)
            model?.predict(on: [clarifaiImage!], completion: {(outputs, error) in
                if error == nil {
                    let output = outputs?[0]
                    var tags = [Any]()
                    for concepts: ClarifaiConcept in (output?.concepts)! {
                        tags.append(concepts.conceptName)
                    }
                    
                    tags = tags.filter({!self.blacklistWords.contains($0 as! String)})
                    
                    var queryStr = tags.description
                    queryStr = queryStr.replacingOccurrences(of: " ", with: "")
                    queryStr.remove(at: queryStr.startIndex)
                    queryStr = queryStr.substring(to: queryStr.index(before: queryStr.endIndex))
                    
                    let url = self.server! + "/analyze/" + queryStr
                    print(queryStr)
                    Alamofire.request(url, method: .get).validate().responseJSON { response in
                        switch response.result {
                        case .success(let value):
                            let json = JSON(value)
                            print("JSON: \(json)")
                        case .failure(let error):
                            print(error)
                        }
                    }
                    
                } else {
                    print("Error: \(String(describing: error?.localizedDescription))")
                }
            })
        })
    }
    
    func loadServerURL() {
        if let url = Bundle.main.url(forResource:"Keys", withExtension: "plist"),
            let keys = NSDictionary(contentsOf: url) as? [String:Any] {
            
            if let serverURL = keys["Server_URL"] as? String {
                server = serverURL
            } else {
                print("Unable to find Server URL")
            }
        } else {
            print("Error: Could not find Keys.plist")
        }
    }
    
}
