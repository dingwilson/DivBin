//
//  UIView+Alerts.swift
//  DivBin
//
//  Created by Wilson Ding on 4/23/17.
//  Copyright © 2017 wilsonding. All rights reserved.
//

import Foundation
import UIKit

extension UIViewController {
    
    //
    // createAlert(title: title, message: message)
    // - Creates an UIAlertController object with a title and message. General use for displaying message to user.
    //
    func createAlert(title: String, message: String) {
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: UIAlertControllerStyle.alert
        )
        
        alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
        
        present(alert, animated: true, completion: nil)
    }
    
    //
    // showTextInputPrompt(withMessage)
    // - Takes in message to display and completion block, and shows prompt with text field and ok/cancel buttons
    //
    
    func showTextInputPrompt(withMessage message: String, completionBlock completion: @escaping (_ userPressedOK: Bool, _ userInput: String?) -> Void) {
        let prompt = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        weak var weakPrompt: UIAlertController? = prompt
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: {(_ action: UIAlertAction) -> Void in
            completion(false, nil)
        })
        
        let okAction = UIAlertAction(title: "Ok", style: .default, handler: {(_ action: UIAlertAction) -> Void in
            let strongPrompt: UIAlertController? = weakPrompt
            completion(true, strongPrompt?.textFields?[0].text)
        })
        
        prompt.addTextField(configurationHandler: nil)
        prompt.addAction(cancelAction)
        prompt.addAction(okAction)
        self.present(prompt, animated: true, completion: { _ in })
    }
}
