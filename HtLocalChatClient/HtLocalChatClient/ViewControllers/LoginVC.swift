//
//  LoginVC.swift
//  HtLocalChatClient
//
//  Created by Ht on 2019/3/26.
//  Copyright © 2019 Ht. All rights reserved.
//

import UIKit

class LoginVC: UIViewController {

    @IBOutlet weak var userNameTF: UITextField!
    @IBOutlet weak var joinBtn: UIButton!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
    }

    @IBAction func join(_ sender: UIButton) {
        UserDefaults.standard.set(userNameTF.text, forKey: "name")
        let list = UserListVC(nibName: "UserListVC", bundle: nil)
        present(list, animated: true, completion: nil)
    }
}
