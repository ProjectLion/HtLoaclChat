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
    var user: String = ""
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        VideoChatManager.shared.call(user: user)
        VideoChatManager.shared.delegate = self
        // Do any additional setup after loading the view.
    }
    
    @IBAction func closeVideo(_ sender: UIButton) {
        VideoChatManager.shared.exitRoom(forUser: user)
        dismiss(animated: true, completion: nil)
    }
    
}

extension VideoChatVC: VideoChatManagerDelegate {
    func videoChat(manager: VideoChatManager, setLocalStream stream: RTCMediaStream, userID id: String) {
        DispatchQueue.main.async {
            let localVideoView = RTCEAGLVideoView(frame: self.myVideoView.bounds)
            let localVideoTrack = stream.videoTracks.last!
//            localVideoTrack.source.adaptOutputFormat(toWidth: 1280, height: 720, fps: 30)
            localVideoTrack.add(localVideoView)
            self.myVideoView.addSubview(localVideoView)
            self.myVideoView.transform = CGAffineTransform(rotationAngle: CGFloat.pi)
        }
    }
}
