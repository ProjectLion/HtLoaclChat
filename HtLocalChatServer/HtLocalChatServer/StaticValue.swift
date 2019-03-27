//
//  StaticValue.swift
//  HtLocalChatServer
//
//  Created by Ht on 2019/3/27.
//  Copyright © 2019 Ht. All rights reserved.
//

import Foundation
import UIKit

public struct StaticValue {
    
    public struct MessageKey {
        static let none = ""
        static let connected = "connected"
        /// 用户列表
        static let userList = "userList"
        /// 用户信息
        static let name = "name"
        /// 呼叫
        static let call = "call"
        /// 被呼叫
        static let called = "called"
        /// 加入房间
        static let join = "join"
        /// 关闭房间
        static let closeRoom = "closeRoom"
        /// 发送加入房间后的反馈(房间内的用户列表)
        static let agree = "agree"
        /// 有人离开房间
        static let leaveRoom = "leaveRoom"
        /// 新加入的人发了ICE候选
        static let iceCandidate = "iceCandidate"
        /// 有新的人员加入
        static let newPeer = "newPeer"
        /// 新加入的人发了offer
        static let offer = "offer"
        /// 回应offer
        static let answer = "answer"
        /// sdp
        static let sdp = "sdp"
        /// 拒绝通话
        static let refuseChat = "refuseChat"
    }
}
