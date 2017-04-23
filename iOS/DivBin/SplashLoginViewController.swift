//
//  SplashLoginViewController.swift
//  DivBin
//
//  Created by Wilson Ding on 4/23/17.
//  Copyright © 2017 wilsonding. All rights reserved.
//

import UIKit
import Firebase
import FirebaseAuth
import GoogleSignIn
import FBSDKCoreKit
import FBSDKLoginKit

class SplashLoginViewController: UIViewController, GIDSignInUIDelegate {
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.view.endEditing(true)
    }
    
    func firebaseLogin(_ credential: FIRAuthCredential) {
        FIRAuth.auth()?.signIn(with: credential) { (user, error) in
            if let error = error {
                self.createAlert(title: "Error", message: error.localizedDescription)
                return
            }
            self.performSegue(withIdentifier: "goToMain", sender: self)
        }
    }
    
    @IBAction func didPressFacebookButton(_ sender: Any) {
        let loginManager = FBSDKLoginManager()
        loginManager.logIn(withReadPermissions: ["email"], from: self, handler: { (result, error) in
            if let error = error {
                self.createAlert(title: "Error", message: error.localizedDescription)
            } else if result!.isCancelled {
                self.createAlert(title: "Error", message: "Facebook login was canceled")
            } else {
                let credential = FIRFacebookAuthProvider.credential(withAccessToken: FBSDKAccessToken.current().tokenString)
                self.firebaseLogin(credential)
            }
        })
    }
    
    @IBAction func didPressGoogleButton(_ sender: Any) {
        GIDSignIn.sharedInstance().uiDelegate = self
        GIDSignIn.sharedInstance().signIn()
    }
    
    @IBAction func backButtonPressed(_ sender: Any) {
        self.performSegue(withIdentifier: "unwindSegue", sender: self)
    }
}
