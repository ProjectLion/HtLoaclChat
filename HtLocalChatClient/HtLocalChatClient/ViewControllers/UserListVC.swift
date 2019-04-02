//
//  UserListVC.swift
//  HtLocalChatClient
//
//  Created by Ht on 2019/3/26.
//  Copyright © 2019 Ht. All rights reserved.
//

import UIKit

class UserListVC: UIViewController {

    @IBOutlet weak var table: UITableView!
    
    var dataSource: [String] = []
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        SocketManager.shared.connct(to: 8848)
        SocketManager.shared.on = { key, data in
            switch key {
            case StaticValue.MessageKey.userList:
                self.dataSource = data as! [String]
                self.table.reloadData()
            case StaticValue.MessageKey.newPeer:
                self.dataSource.append(data as! String)
                self.table.reloadData()
            case StaticValue.MessageKey.call:     // 被呼叫
                let dict = data as! Dictionary<String, String>
                let caller = dict["caller"]
                let alert = UIAlertController(title: nil, message: "\(caller!)请求通话", preferredStyle: .alert)
                let action1 = UIAlertAction(title: "同意", style: .default, handler: { (action) in
                    
                    let videoVC = VideoChatVC(nibName: "VideoChatVC", bundle: nil)
                    videoVC.userName = caller!          // 自己是被叫方，所以将主叫的name传过去
                    videoVC.isCaller = false
                    self.present(videoVC, animated: true, completion: nil)
                })
                let action2 = UIAlertAction(title: "拒绝", style: .destructive, handler: { (action) in
                    // 同意以后开始创建连接、本地视频流、offer并将offer发送给对方
//                    SocketManager.shared.sendMessage(type: StaticValue.MessageKey.agree, data: data)
                })
                alert.addAction(action1)
                alert.addAction(action2)
                self.present(alert, animated: true, completion: nil)
            default:
                break
            }
        }
        table.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        table.rowHeight = 44
        table.dataSource = self
        table.delegate = self
        view.addSubview(table)
        // Do any additional setup after loading the view.
    }

}
extension UserListVC: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource.count
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = table.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = dataSource[indexPath.row]
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let videoVC = VideoChatVC(nibName: "VideoChatVC", bundle: nil)
        videoVC.userName = dataSource[indexPath.row]
        present(videoVC, animated: true, completion: nil)
    }
}
