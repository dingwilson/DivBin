//
//  ProfileViewController.swift
//  DivBin
//
//  Created by Wilson Ding on 4/23/17.
//  Copyright © 2017 wilsonding. All rights reserved.
//

import UIKit
import Eureka
import Firebase
import FirebaseDatabase
import GoogleSignIn
import FBSDKCoreKit
import FBSDKLoginKit

enum AuthProvider {
    case authFacebook
    case authGoogle
}

class ProfileViewController: FormViewController, GIDSignInUIDelegate {
    
    var savedImage : UIImage?
    
    var savedUsername : String = ""
    var savedEmail : String = ""
    var savedUID : String = ""
    var savedMoney : Float = 0.00
    
    var isAuthViaFacebook : Bool = false
    var isAuthViaGoogle : Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        getData()
        
        buildForm()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        getData()
    }
    
    func getData() {
        if let user = FIRAuth.auth()?.currentUser {
            if let email = user.email {
                self.savedEmail = email // Get User Email
            }
            
            self.savedUID = user.uid // Get User UID
            
            let ref = FIRDatabase.database().reference()
            
            // Get User Username
            ref.child("Users/\(self.savedUID)/Username").observeSingleEvent(of: .value, with: { (snapshot) in
                guard let username = snapshot.value as? String else {
                    return
                }
                self.savedUsername = username
                
                self.form.rowBy(tag: "usernameRow")?.updateCell()
                self.tableView?.reloadData()
            })
            
            ref.child("Users/\(self.savedUID)/Balance").observeSingleEvent(of: .value, with: { (snapshot) in
                guard let balance = snapshot.value as? Float else {
                    return
                }
                
                self.savedMoney = balance
                
                self.form.rowBy(tag: "currentMoneyRow")?.updateCell()
                self.tableView?.reloadData()
            })
            
            // Get User Photo
            let photoURL = user.photoURL
            
            struct last {
                static var photoURL : URL? = nil
            }
            
            last.photoURL = photoURL
            
            if let photoURL = photoURL {
                let data = try? Data.init(contentsOf: photoURL)
                if let data = data {
                    let image = UIImage.init(data: data)
                    
                    if photoURL == last.photoURL {
                        self.savedImage = image
                    }
                }
            } else {
                self.savedImage = UIImage(named: "GenericProfilePhoto")
            }
            
            // Get User Provider List
            let userProviders = FIRAuth.auth()?.currentUser?.providerData
            
            for provider in userProviders! {
                if provider.providerID == FIRFacebookAuthProviderID {
                    self.isAuthViaFacebook = true
                } else if provider.providerID == FIRGoogleAuthProviderID {
                    self.isAuthViaGoogle = true
                }
            }
            
            self.tableView?.reloadData()
            
        } else {
            self.createAlert(title: "Error", message: "Oops, you don't seem to be signed in...")
        }
    }
    
    func buildForm() {
        form +++
            Section(){ section in
                section.header = {
                    var header = HeaderFooterView<UIView>(.callback({
                        let view = UIView(frame: CGRect(x: 0, y: 0, width: self.view.bounds.width, height: self.view.bounds.width))
                        
                        let imageView = UIImageView(image: self.savedImage)
                        imageView.contentMode = .scaleAspectFit
                        
                        imageView.frame = CGRect(x: self.view.bounds.width/4, y: self.view.bounds.width/16, width: self.view.bounds.width/2, height: self.view.bounds.width/2)
                        
                        imageView.layer.cornerRadius = imageView.frame.width/2
                        imageView.layer.masksToBounds = true
                        imageView.layer.borderWidth = 0
                        
                        view.addSubview(imageView)
                        
                        return view
                    }))
                    
                    header.height = { self.view.bounds.width/1.75 }
                    return header
                }()
            }
            
            +++ Section("Account Information")
            
            <<< EmailRow(){
                $0.title = "\(self.savedUsername)"
                $0.disabled = true
                $0.tag = "usernameRow"
                $0.value = "\(savedEmail)"
                }.cellUpdate { cell, row in
                    row.title = "\(self.savedUsername)"
            }
            
            <<< LabelRow(){
                $0.title = "Current Money: "
                $0.tag = "currentMoneyRow"
                $0.value = "$\(self.savedMoney)"
                }.cellUpdate { cell, row in
                    row.value = "$\(self.savedMoney)"
            }
            
            +++ Section("Payment Methods")
            
            <<< LabelRow(){
                $0.title = "Credit Card"
                }.onCellSelection { _,_ in
                    self.showTextInputPrompt(withMessage: "Credit Card Number:") { (userPressedOK, userInput) in
                        if userInput != nil {
                            //
                        } else {
                            self.createAlert(title: "Error", message: "Credit Card Number cannot be empty")
                        }
                    }
                }
            
            <<< LabelRow(){
                $0.title = "Link Bank Account"
                }.onCellSelection { _,_ in
                    self.showTextInputPrompt(withMessage: "Bank Account Number:") { (userPressedOK, userInput) in
                        if userInput != nil {
                            //
                        } else {
                            self.createAlert(title: "Error", message: "Bank Account Number cannot be empty")
                        }
                    }
            }
            
            +++ Section("Account Actions")
            
            <<< LabelRow(){
                $0.title = "Change Email"
                }.onCellSelection { _,_ in
                    self.showTextInputPrompt(withMessage: "Email Address:") { (userPressedOK, userInput) in
                        if let userInput = userInput {
                            FIRAuth.auth()?.currentUser?.updateEmail(userInput) { (error) in
                                self.showTypicalUIForUserUpdateResults(withTitle: "Change Email", error: error)
                            }
                        } else {
                            self.createAlert(title: "Error", message: "Email cannot be empty")
                        }
                    }
            }
            
            <<< LabelRow(){
                $0.title = "Change Password"
                }.onCellSelection { _,_ in
                    self.showTextInputPrompt(withMessage: "New Password:") { (userPressedOK, userInput) in
                        if let userInput = userInput {
                            FIRAuth.auth()?.currentUser?.updatePassword(userInput) { (error) in
                                self.showTypicalUIForUserUpdateResults(withTitle: "Change Password", error: error)
                            }
                        } else {
                            self.createAlert(title: "Error", message: "Password cannot be empty")
                        }
                    }
            }
            
            <<< LabelRow(){
                $0.title = "Sign Out"
                }.onCellSelection { _,_ in
                    let firebaseAuth = FIRAuth.auth()
                    do {
                        try firebaseAuth?.signOut()
                        self.performSegue(withIdentifier: "didSignOut", sender: self)
                    } catch let signOutError as NSError {
                        print ("Error signing out: %@", signOutError)
                    }
        }
    }
    
    func firebaseLogin(_ credential: FIRAuthCredential) {
        if let user = FIRAuth.auth()?.currentUser { // Linking Credentials
            user.link(with: credential) { (user, error) in
                if let error = error {
                    self.createAlert(title: "Error", message: error.localizedDescription)
                    return
                }
                self.getData()
            }
        } else {
            self.createAlert(title: "Error", message: "Error, you are not currently logged in.")
        }
    }

    func showTypicalUIForUserUpdateResults(withTitle resultsTitle: String, error: Error?) {
        if let error = error {
            let message = "\(error.localizedDescription)"
            let okAction = UIAlertAction.init(title: "OK", style: .default) {
                action in
                // print("OK")
            }
            let alertController  = UIAlertController.init(title: resultsTitle,
                                                          message: message, preferredStyle: .alert)
            alertController.addAction(okAction)
            self.present(alertController, animated: true, completion: nil)
            return
        }
    }
}
