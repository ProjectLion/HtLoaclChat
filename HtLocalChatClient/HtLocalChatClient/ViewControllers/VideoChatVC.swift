//
//  VideoChatVC.swift
//  HtLocalChatClient
//
//  Created by Ht on 2019/3/27.
//  Copyright © 2019 Ht. All rights reserved.
//

import UIKit
import WebRTC

class VideoChatVC: UIViewController {
    
    
    @IBOutlet weak var myVideoView: UIView!
    
    @IBOutlet weak var remote: UIView!
    // 远程视频流追踪   看网上有人说要将该追踪对象持有，否则对方视频会黑屏，不知道为啥
    private var remoteVideoTrack: RTCVideoTrack!
    // 本地视频流追踪
    private var localVideoTrack: RTCVideoTrack!
    
    /// 是否是主叫方
    var isCaller = true
    /// 发送消息的目标name
    var userName = ""
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        VideoChatManager.shared.setUp()
        VideoChatManager.shared.delegate = self
        // Do any additional setup after loading the view.
    }
    
    @IBAction func closeVideo(_ sender: UIButton) {
//        VideoChatManager.shared.exitRoom(forUser: user)
        dismiss(animated: true, completion: nil)
    }
    
}

extension VideoChatVC: VideoChatManagerDelegate {
    func videoChat(manager: VideoChatManager, setLocalStream stream: RTCMediaStream, userID id: String) {
        if isCaller {
            // 让服务器帮忙呼叫指定的人
            SocketManager.shared.sendMessage(type: StaticValue.MessageKey.call, data: ["caller": UserDefaults.standard.string(forKey: "name")!, "called": userName])
        } else {
            
            SocketManager.shared.sendMessage(type: StaticValue.MessageKey.agree, data: ["caller": userName, "called": UserDefaults.standard.string(forKey: "name")!])
        }
        DispatchQueue.main.async {
            guard let videoTrack = stream.videoTracks.last else {
                ht_print(message: "本地视频go die了")
                return
            }
            let localVideoView = RTCEAGLVideoView(frame: self.myVideoView.bounds)
            self.localVideoTrack = videoTrack
            self.localVideoTrack.add(localVideoView)
            localVideoView.transform = CGAffineTransform(rotationAngle: CGFloat.pi)
            self.myVideoView.addSubview(localVideoView)
        }
    }
    func videoChat(manager: VideoChatManager, addRemoteStream stream: RTCMediaStream, userID id: String) {
        ht_print(message: "收到远程视频流: \(stream.videoTracks.first)")
        DispatchQueue.main.async {
            guard let videoTrack = stream.videoTracks.last else {
                ht_print(message: "远程视频go die了")
                return
            }
            self.remoteVideoTrack = videoTrack
            let remoteVideoView = RTCEAGLVideoView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width*0.5, height: UIScreen.main.bounds.height*0.5))
            
            self.remoteVideoTrack.add(remoteVideoView)
            remoteVideoView.transform = CGAffineTransform(rotationAngle: .pi)
            self.view.addSubview(remoteVideoView)
        }
    }
}
