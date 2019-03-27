//
//  ViewController.swift
//  HtLocalChatServer
//
//  Created by Ht on 2019/3/26.
//  Copyright © 2019 Ht. All rights reserved.
//

import UIKit
import MBProgressHUD

class ViewController: UIViewController {

    @IBOutlet weak var ipLabel: UILabel!
    @IBOutlet weak var lisenBtn: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        ipLabel.text = ipLabel.text! + SocketManager.ipAddress
        
        // Do any additional setup after loading the view, typically from a nib.
    }

    @IBAction func lisen(_ sender: Any) {
        if (sender as! UIButton).isSelected {
//            SocketManager.shared.disConnect()
            lisenBtn.isSelected = false
            ht_print(message: "")
        } else {
            SocketManager.shared.accept(on: 8848, success: {
                let hud = MBProgressHUD.showAdded(to: self.view, animated: true)
                hud.mode = .text
                hud.label.text = "监听成功"
                self.lisenBtn.isSelected = true
                hud.hide(animated: true, afterDelay: 2)
            }) {
                let hud = MBProgressHUD.showAdded(to: self.view, animated: true)
                hud.mode = .text
                hud.label.text = "监听失败"
                hud.hide(animated: true, afterDelay: 2)
            }
        }
    }
}

