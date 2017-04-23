//
//  SplashViewController.swift
//  DivBin
//
//  Created by Wilson Ding on 4/21/17.
//  Copyright © 2017 wilsonding. All rights reserved.
//

import UIKit
import SwiftVideoBackground

class SplashViewController: UIViewController {
    
    @IBOutlet weak var statusLabel: UILabel!
    
    let statusInterval: TimeInterval = 5
    
    var checkTimer: Timer!
    
    override var prefersStatusBarHidden : Bool {
        return true
    }
    
    var statuses: [String] = ["It takes 95 percent less energy to make an aluminum can out of recycled aluminum than out of raw virgin materials.","Recycling is a $200 billion industry in the U.S.","About one-third of an average dump is made up of packaging material!","Recycling conserves fresh water up to 95% in the mining and manufacturing process for many materials.","The U.S. recycling levels have not improved in 20 years despite the billions of dollars spent on recycling competitions, symposiums, awareness campaigns and new sorting technologies.","Recycling Significantly reduces use of fossil fuel energy and reduces CO2 emissions.","Every month, we throw out enough glass bottles and jars to fill up a giant skyscraper. All of these jars are recyclable!","We use over 80,000,000,000 aluminum soda cans every year.","If all our newspaper was recycled, we could save about 250,000,000 trees each year!","Approximately 1 billion trees worth of paper are thrown away every year in the U.S.","Plastic bags and other plastic garbage thrown into the ocean kill as many as 1,000,000 sea creatures every year!","The energy saved from recycling one glass bottle can run a 100-watt light bulb for four hours or a compact fluorescent bulb for 20 hours. It also causes 20% less air pollution and 50% less water pollution than when a new bottle is made from raw materials.","Recycling plastic saves twice as much energy as burning it in an incinerator.","The amount of wood and paper we throw away each year is enough to heat 50,000,000 homes for 20 years."]

    @IBOutlet weak var backgroundVideo: BackgroundVideo!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        backgroundVideo.createBackgroundVideo(name: "Flying-Birds", type: "mp4")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        setStatus()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.checkTimer = Timer.scheduledTimer(timeInterval: statusInterval, target: self, selector: #selector(self.setStatus), userInfo: nil, repeats: true)
    }
    
    func setStatus() {
        let randomNum:UInt32 = arc4random_uniform(14)
        
        let index:Int = Int(randomNum)
        
        statusLabel.text = statuses[index]
        
        statusLabel.fadeIn()
        statusLabel.fadeOut()
    }

}

extension UIView {
    func fadeIn(duration: TimeInterval = 1.0, delay: TimeInterval = 0.0, completion: @escaping ((Bool) -> Void) = {(finished: Bool) -> Void in}) {
        UIView.animate(withDuration: duration, delay: delay, options: UIViewAnimationOptions.curveEaseIn, animations: {
            self.alpha = 1.0
        }, completion: completion)  }
    
    func fadeOut(duration: TimeInterval = 1.0, delay: TimeInterval = 3.0, completion: @escaping (Bool) -> Void = {(finished: Bool) -> Void in}) {
        UIView.animate(withDuration: duration, delay: delay, options: UIViewAnimationOptions.curveEaseIn, animations: {
            self.alpha = 0.0
        }, completion: completion)
    }
    
}
