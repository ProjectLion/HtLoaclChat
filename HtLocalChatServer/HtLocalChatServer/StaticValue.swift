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
    
    /// 消息key
    public struct MessageKey {
        
        static let none = ""
        
        static let name = "name"
        
        static let connected = "connected"
        
        static let userList = "userList"
        
        /// 用户列表, 当前用户信息(socket连接成功时发送服务器用户列表和当前用户信息到服务端)
        static let usersDesc = "usersDesc"     // 数据格式 {"userList": ["user1": "", "user2": ""], "name": "当前用户名"}
        /// 呼叫
        static let call = "call"    // 数据格式 {"caller": "主叫方用户名", "called": "被叫方用户名"}
        /// 同意通话
        static let agree = "agree"      // 数据格式 {"caller": "主叫方用户名", "called": "被叫方用户名", "userList": ["", ""]}
        /// 拒绝通话
        static let refuseChat = "refuseChat"    // 数据格式 {"caller": "主叫方用户名", "called": "被叫方用户名"}
        /// 关闭房间
        static let closeRoom = "closeRoom"
        /// 有人离开房间
        static let leaveRoom = "leaveRoom"      // 数据格式 {"name": "离开房间的人"}
        /// 新加入的人发了ICE候选
        static let iceCandidate = "iceCandidate"
        /// 有新的人员加入
        static let newPeer = "newPeer"          // 数据格式 {"name": "新加入的人"}
        /// offer
        static let offer = "offer"      //
        /// 回应offer
        static let answerOffer = "answerOffer"
    }
}
