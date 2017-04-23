//
//  MainScrollViewController.swift
//  DivBin
//
//  Created by Wilson Ding on 4/23/17.
//  Copyright © 2017 wilsonding. All rights reserved.
//

import UIKit

class MainScrollViewController: UIViewController {
    
    private let vcInScrollView : [String] = ["ProfileView", "PledgeView", "CameraView"]
    
    private let indexOfInitialVC : CGFloat = 1 // Index of Initial VC to show
    
    override var prefersStatusBarHidden : Bool { // Hide Status Bar for CameraVC
        return true
    }
    
    @IBOutlet weak var scrollView: UIScrollView!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupScrollView(viewcontrollers: vcInScrollView)
    }
    
    func setupScrollView(viewcontrollers: [String]) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        
        for (index, identifier) in viewcontrollers.enumerated() {
            let childVC = storyboard.instantiateViewController(withIdentifier: identifier)
            
            var childFrame = childVC.view.frame
            childFrame.origin.x = self.view.frame.size.width * CGFloat(index)
            childVC.view.frame = childFrame
            
            self.addChildViewController(childVC)
            self.scrollView.addSubview(childVC.view)
            childVC.didMove(toParentViewController: self)
        }
        
        self.scrollView.contentSize = CGSize(width: self.view.frame.size.width * CGFloat(vcInScrollView.count), height: self.view.frame.size.height)
        
        self.scrollView.contentOffset = CGPoint(x: self.view.frame.size.width * indexOfInitialVC, y: 0)
    }
}
