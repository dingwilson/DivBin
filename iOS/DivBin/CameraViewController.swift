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
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var incorrectButton: UIButton!
    @IBOutlet weak var fourthDescription: UILabel!
    @IBOutlet weak var thirdDescription: UILabel!
    @IBOutlet weak var secondDescription: UILabel!
    @IBOutlet weak var firstDescription: UILabel!
    
    let cameraTimerInterval: TimeInterval = 3
    
    let blacklistWords: [String] = ["abstract", "adult", "art", "artistic", "astronomy", "background", "blur", "bright", "building", "business", "car", "color", "commerce", "conceptual", "connection", "contemporary", "dark", "design", "drag race", "drive", "eclipse", "education", "equipment", "exhibition", "family", "financial security", "futuristic", "indoors", "industry", "insubstantial", "internet", "landscape", "light", "Luna", "luxury", "money", "modern", "moon", "museum", "music", "no person", "offense", "office", "one", "pattern", "people", "performance", "portrait", "recreation", "room", "science", "shining", "sky", "stripe", "transportation system", "travel", "vehicle", "wallpaper", "window"]
    
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
        
        titleLabel.isHidden = true
        incorrectButton.isHidden = true
        firstDescription.isHidden = true
        secondDescription.isHidden = true
        thirdDescription.isHidden = true
        fourthDescription.isHidden = true
        
        loadCamera()
        
        self.checkTimer = Timer.scheduledTimer(timeInterval: cameraTimerInterval, target: self, selector: #selector(self.takePhoto), userInfo: nil, repeats: true)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if captureSession!.isRunning {
            captureSession!.stopRunning()
        }
        
        self.checkTimer.invalidate()
    }
    
    func loadClarifaiKeys() {
        if let url = Bundle.main.url(forResource:"Keys", withExtension: "plist"),
            let keys = NSDictionary(contentsOf: url) as? [String:Any] {
            
            if let clarifaiClientID = keys["Clarifai_Client_ID"] as? String {
                if let clarifaiClientSecret = keys["Clarifai_Client_Secret"] as? String {
                    app = ClarifaiApp(appID: clarifaiClientID, appSecret: clarifaiClientSecret)
                } else {
                    fatalError("Error: Clarifai_Client_Secret not found in Keys.plist")
                }
            } else {
                fatalError("Error: Clarifai_Client_ID not found in Keys.plist")
            }
        } else {
            fatalError("Error: Could not find Keys.plist")
        }
    }
    
    func loadCamera() {
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = AVCaptureSessionPresetPhoto
        cameraOutput = AVCapturePhotoOutput()
        
        let device = findDefaultDevice()
        
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
                fatalError("Error: Cannot add input to captureSession")
            }
            
            do {
                try device.lockForConfiguration()
                
                let focusPoint = CGPoint(x: 0.5, y: 0.5)
                
                device.focusPointOfInterest = focusPoint
                device.focusMode = .continuousAutoFocus
                device.exposurePointOfInterest = focusPoint
                device.exposureMode = AVCaptureExposureMode.continuousAutoExposure
                device.unlockForConfiguration()
            } catch {
                // just ignore fail of autofocus
            }
        } else {
            fatalError("Error: Cannot setup input for captureSession")
        }
    }
    
    func findDefaultDevice() -> AVCaptureDevice {
        if let device = AVCaptureDevice.defaultDevice(withDeviceType: AVCaptureDeviceType.builtInDualCamera,
                                                      mediaType: AVMediaTypeVideo,
                                                      position: .back) {
            return device // use dual camera on supported devices
        } else if let device = AVCaptureDevice.defaultDevice(withDeviceType: AVCaptureDeviceType.builtInWideAngleCamera,
                                                             mediaType: AVMediaTypeVideo,
                                                             position: .back) {
            return device // use default back facing camera otherwise
        } else {
            fatalError("All supported devices are expected to have at least one of the queried capture devices.")
        }
    }
    
    func takePhoto() {
        let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecJPEG,
                                                       AVVideoCompressionPropertiesKey: [AVVideoQualityKey : NSNumber(value: 0.7)]])
        
        let cameraQueue = DispatchQueue(label: "com.wilsonding.CameraQueue")
        
        cameraQueue.async {
            let previewPixelType = settings.availablePreviewPhotoPixelFormatTypes.first!
            let previewFormat = [
                kCVPixelBufferPixelFormatTypeKey as String: previewPixelType,
                kCVPixelBufferWidthKey as String: 160,
                kCVPixelBufferHeightKey as String: 160
            ]
            settings.previewPhotoFormat = previewFormat
        
            self.cameraOutput?.capturePhoto(with: settings, delegate: self)
        }
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
            
            let processQueue = DispatchQueue(label: "com.wilsonding.ImageProcessing")
            
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
                    
                    DispatchQueue.main.async {
                        self.titleLabel.text = tags[0] as? String
                        self.titleLabel.isHidden = false
                        self.incorrectButton.isHidden = false
                    }
                    
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
                fatalError("Unable to find Server URL")
            }
        } else {
            fatalError("Error: Could not find Keys.plist")
        }
    }
    
    @IBAction func didPressIncorrectButton(_ sender: Any) {
        self.performSegue(withIdentifier: "goToSelection", sender: self)
    }
}
