//
//  UsersManager.swift
//  HtLocalChatServer
//
//  Created by Ht on 2019/3/27.
//  Copyright © 2019 Ht. All rights reserved.
//

import UIKit
import CocoaAsyncSocket

///
class UsersManager: NSObject {
    /// 单例
    static let shared = UsersManager()
    private override init() {
    }
    /// 用户对应的socket
    var userSocket: [String: GCDAsyncSocket] = [:]
    
}
