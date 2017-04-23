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
    
    override var prefersStatusBarHidden : Bool {
        return true
    }

    @IBOutlet weak var previewView: UIView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var incorrectButton: UIButton!
    @IBOutlet weak var fourthDescription: UILabel!
    @IBOutlet weak var thirdDescription: UILabel!
    @IBOutlet weak var secondDescription: UILabel!
    @IBOutlet weak var firstDescription: UILabel!

    var descriptionArray: [String] = []

    let cameraTimerInterval: TimeInterval = 2

    let blacklistWords: [String] = ["abstract", "action", "adolescent", "adult", "aircraft", "architecture", "art", "artistic", "astronomy", "auto racing", "background", "band", "banking", "bathroom", "battle", "bird", "blur", "bright", "building", "business", "car", "carnival", "celebration", "ceremony", "city", "color", "commerce", "competition", "conceptual", "concert", "connection", "contemporary", "craft", "creativity", "danger", "dark", "daylight", "design", "displayed", "drag race", "drive", "eclipse", "education", "empty", "environment", "equipment", "exhibition", "face", "family", "fashion", "festival", "financial security", "flame", "futuristic", "girl", "grinder", "group", "hairdo", "healthcare", "horizontal", "illuminated", "illustration", "indoors", "industry", "inside", "insubstantial", "internet", "landscape", "light", "Luna", "luxury", "man", "many", "military", "mirror", "money", "modern", "moon", "motion", "movie", "museum", "music", "musician", "nature", "nightclub", "no person", "offense", "office", "one", "outdoors", "pattern", "people", "performance", "police", "portrait", "production", "public show", "race", "recreation", "reflection", "room", "science", "school", "screen", "service", "shining", "shopping", "side view", "singer", "skill", "sky", "space", "stage", "strange", "street", "soap", "sound", "spotlight", "still life", "stock", "stripe", "text", "texture", "transportation system", "travel", "urban", "vector", "vehicle", "vertical", "wallpaper", "wear", "window", "woman", "young"]

    var captureSession: AVCaptureSession?
    var cameraOutput: AVCapturePhotoOutput?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var currentImage: UIImage?

    var app: ClarifaiApp?
    var server: String?
    
    var tags = [Any]()

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
        secondDescription.isHidden = true
        thirdDescription.isHidden = true
        fourthDescription.isHidden = true
        
        firstDescription.text = "Point your camera at an object to begin..."
        
        loadCamera()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
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
        captureSession?.sessionPreset = AVCaptureSessionPreset640x480
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
                                                       AVVideoCompressionPropertiesKey: [AVVideoQualityKey : NSNumber(value: 0.2)]])
        
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
            
            DispatchQueue.main.async {
                self.currentImage = image
            }
            
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
                    self.tags = [Any]()
                    for concepts: ClarifaiConcept in (output?.concepts)! {
                        self.tags.append(concepts.conceptName)
                    }
                    
                    self.tags = self.tags.filter({!self.blacklistWords.contains($0 as! String)})
                    
                    DispatchQueue.main.async {
                        self.titleLabel.text = self.tags[0] as? String
                        self.titleLabel.isHidden = false
                        self.incorrectButton.isHidden = false
                    }
                    
                    var queryStr = self.tags.description
                    queryStr = queryStr.replacingOccurrences(of: " ", with: "")
                    queryStr.remove(at: queryStr.startIndex)
                    queryStr = queryStr.substring(to: queryStr.index(before: queryStr.endIndex))
                    
                    let url = self.server! + "/analyze/" + queryStr
                    Alamofire.request(url, method: .get).validate().responseJSON { response in
                        switch response.result {
                        case .success(let value):
                            let json = JSON(value)
                            let trash = json["Trash"].doubleValue
                            let donate = json["Donate"].doubleValue
                            let compost = json["Compost"].doubleValue
                            let recycle = json["Recycle"].doubleValue
                            
                    
                            let dict = [
                                "Trash":trash,
                                "Donate":donate,
                                "Compost":compost,
                                "Recycle":recycle
                            ]
                            
                            let sorted = dict.sorted(by: {
                                let obj1 = dict[$0.key]
                                let obj2 = dict[$1.key]
                                if (obj1! - obj2! > 0) {
                                    return true
                                }
                                return false
                            })
                            
                            for item in sorted {
                                if (item.value != 0.0) {
                                    self.descriptionArray.append("\(item.key): \(Double(round(100*item.value)/100) * 100)%")
                                }
                            }
                            
                            DispatchQueue.main.async {
                                self.updatePercentages()
                            }
                            
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

    func updatePercentages() {
            self.firstDescription.isHidden = true
            self.secondDescription.isHidden = true
            self.thirdDescription.isHidden = true
            self.fourthDescription.isHidden = true
            
            switch self.descriptionArray.count {
            case 0: self.firstDescription.text = "Object not recognized. Help manually input this!"
                    self.firstDescription.isHidden = false
                
            case 1: self.firstDescription.text = self.descriptionArray[0]
                    self.firstDescription.isHidden = false
                
            case 2: self.secondDescription.text = self.descriptionArray[0]
                    self.firstDescription.text = self.descriptionArray[1]
                    self.secondDescription.isHidden = false
                    self.firstDescription.isHidden = false
                
            case 3: self.thirdDescription.text = self.descriptionArray[0]
                    self.secondDescription.text = self.descriptionArray[1]
                    self.firstDescription.text = self.descriptionArray[2]
                    self.thirdDescription.isHidden = false
                    self.secondDescription.isHidden = false
                    self.firstDescription.isHidden = false
                
                
            case 4: self.fourthDescription.text = self.descriptionArray[0]
                    self.thirdDescription.text = self.descriptionArray[1]
                    self.secondDescription.text = self.descriptionArray[2]
                    self.firstDescription.text = self.descriptionArray[3]
                    self.fourthDescription.isHidden = false
                    self.thirdDescription.isHidden = false
                    self.secondDescription.isHidden = false
                    self.firstDescription.isHidden = false
                
            default: print("Error: There are more than 4 items")
            }
        
        self.descriptionArray = []
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

    @IBAction func unwindToVC(segue: UIStoryboardSegue) { // Unwinding segue

    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let navVC = segue.destination as? UINavigationController{
            if let nextVC = navVC.viewControllers[0] as? SelectionRootViewController {
                nextVC.tags = self.tags
                nextVC.currentImage = currentImage
            }
        }
    }
    
}
