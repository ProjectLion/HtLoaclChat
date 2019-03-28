//
//  SocketManager.swift
//  HtLocalChatServer
//
//  Created by Ht on 2019/3/26.
//  Copyright © 2019 Ht. All rights reserved.
//

import UIKit
import CocoaAsyncSocket

/// Debug输出
public func ht_print<T>(message: T, file: String = #file, line: Int = #line, method: String = #function) {
    #if DEBUG
    print("\((file as NSString).lastPathComponent)文件的第\(line)行,log:\n\(message)\n")
    #endif
}

/// Int 转 Data
public func intToData(withValue value: Int) -> Data {
    var byte: [UInt8] = [0,0,0,0]
    byte[0] = (UInt8)((value>>24) & 0xFF)
    byte[1] = (UInt8)((value>>16) & 0xFF)
    byte[2] = (UInt8)((value>>8) & 0xFF)
    byte[3] = (UInt8)((value>>0) & 0xFF)
    return Data(bytes: byte, count: 4)
}
/// Data 转 Int
public func dataToInt(withData data: Data) -> Int {
    var byte: [UInt8] = [0,0,0,0]
    //   (data as NSData).getBytes(&byte, length: 4)
    data.copyBytes(to: &byte, from: 0..<4)
    var value: Int = 0
    let one = (byte[0] & 0xFF)<<24
    let two = (byte[1] & 0xFF)<<16
    let three = (byte[2] & 0xFF)<<8
    let four = byte[3] & 0xFF
    value = (Int)(one | two | three | four)
    // 下面这种写法就不行,IDE辣鸡！
    //    value = (Int)(((byte[0] & 0xFF)<<24) | ((byte[1] & 0xFF)<<16) | ((byte[2] & 0xFF)<<8) | (byte[3] & 0xFF))
    return value
}
/// 将字典转为字符串
public func dictToString(dict: Dictionary<String, Any>) -> String {
    let jsonData = try! JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted)
    return String(data: jsonData, encoding: .utf8)!
}

/// socket管理类
class SocketManager: NSObject {
    
    private let delegateQueue = DispatchQueue(label: "com.delegate.queue")
    private let socketQueue = DispatchQueue(label: "com.socket.queue")
    
    /// 单例
    static let shared = SocketManager()
    private override init() {
    }
    
    /// 获取本机IP地址
    static var ipAddress: String {
        var addresses = [String]()
        var ifaddr : UnsafeMutablePointer<ifaddrs>? = nil
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while (ptr != nil) {
                let flags = Int32(ptr!.pointee.ifa_flags)
                var addr = ptr!.pointee.ifa_addr.pointee
                if (flags & (IFF_UP|IFF_RUNNING|IFF_LOOPBACK)) == (IFF_UP|IFF_RUNNING) {
                    if addr.sa_family == UInt8(AF_INET) || addr.sa_family == UInt8(AF_INET6) {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        if (getnameinfo(&addr, socklen_t(addr.sa_len), &hostname, socklen_t(hostname.count),nil, socklen_t(0), NI_NUMERICHOST) == 0) {
                            if let address = String(validatingUTF8:hostname) {
                                addresses.append(address)
                            }
                        }
                    }
                }
                ptr = ptr!.pointee.ifa_next
            }
            freeifaddrs(ifaddr)
        }
        return addresses.first ?? "0.0.0.0"
    }
    
    /// 服务端socket，负责监听端口
    var socket: GCDAsyncSocket?
    
    private var room: [String] = []
    
    /// 缓冲池
    private var bufferPool: [String: GCDAsyncSocket] = [:]
    
    /// 注销时清洗缓冲池
    public func logout() {
        for item in bufferPool.values {
            item.readStream()?.release()
            item.writeStream()?.release()
            item.disconnect()
        }
        bufferPool.removeAll()
    }
    
    /// 发送消息给客户端
    ///
    /// - Parameters:
    ///   - type: 消息类型
    ///   - data: 想要发送的数据
    ///   - socket: socket
    private func sendMessage(type: String, data: Any, socket: GCDAsyncSocket) {
        let data = dictToString(dict: ["type": type, "data": data]).data(using: .utf8)
//        var intData = intToData(withValue: data!.count)
//        intData.append(data!)
        socket.write(data!, withTimeout: 1, tag: 0)
    }
    
}

extension SocketManager: GCDAsyncSocketDelegate {
    // 收到新的socket连接时的回调
    func socket(_ sock: GCDAsyncSocket, didAcceptNewSocket newSocket: GCDAsyncSocket) {
        
        ht_print(message: "有新的连接加入,IP为：\(newSocket.connectedHost ?? "")")
        
        var arr: [String] = []
        // 当有新用户加入时将用户列表返给新用户
        for item in UsersManager.shared.userSocket.keys {
            arr.append(item)
        }
        sendMessage(type: StaticValue.MessageKey.userList, data: arr, socket: newSocket)
        
        // 将新连接加入缓冲池
        bufferPool[newSocket.connectedHost!] = newSocket
        // 同时读取客户端的消息(该方法会触发 socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) 回调)
        // 因为我们做的是服务器。所以要循环监听缓冲池中的所有socket
        for item in bufferPool.values {
            // 读取(监听)客户端的消息
            item.readData(withTimeout: -1, tag: 1)
        }
    }
    
    /// readData(withTimeout: Int, tag: Int) 的回调
    func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
        // 包头(包头包含了正文的数据长度)
//        let headData = data.subdata(in: 0..<4)
//        // 正文length
//        let strLength = dataToInt(withData: headData)
        let desc = String(data: data, encoding: .utf8)
        ht_print(message: "正文: \(desc!)")
        var dic: Dictionary<String, Any> = [:]
        do {
            dic = try JSONSerialization.jsonObject(with: data, options: [.mutableLeaves, .allowFragments]) as! Dictionary<String, Any>
        } catch let error {
            ht_print(message: error)
        }
        switch dic["type"] as! String {
        case StaticValue.MessageKey.name:
            let name = dic["data"] as! String
            // 当收到新用户的name时，将其分发给所有连接上的用户，通知他们刷新UI
            for item in UsersManager.shared.userSocket.keys {
                sendMessage(type: StaticValue.MessageKey.newUser, toUser: item, data: name)
            }
            // 将新用户的信息保存起来
            UsersManager.shared.userSocket[name] = sock
        case StaticValue.MessageKey.call:       // 收到呼叫信息后将通话请求转发给 called(被叫)  caller(主叫)
            
            let dat = dic["data"] as! Dictionary<String, String>
            let called = dat["called"]
            // 将主叫方添加到房间
            room.append(dat["caller"]!)
            sendMessage(type: StaticValue.MessageKey.called, toUser: called!, data: dat)
        case StaticValue.MessageKey.agree:      // 被叫方同意通话 将消息转发给主叫方
            let dat = dic["data"] as! Dictionary<String, String>
            let caller = dat["caller"]
            // 被叫放同意通话后将其加入房间
            room.append(dat["called"]!)
            sendMessage(type: StaticValue.MessageKey.agree, toUser: caller!, data: room)
        case StaticValue.MessageKey.offer:            // 有人发了offer
            let dat = dic["data"] as! Dictionary<String, Any>
            let called = dat["called"] as! String
            // 将这个offer发送给房间里的所有人
            sendMessage(type: StaticValue.MessageKey.offer, toUser: called, data: dat)
        case StaticValue.MessageKey.answer:         // 回复offer
            let dat = dic["data"] as! Dictionary<String, Any>
            let caller = dat["caller"] as! String
            // 将这个answer发送给发offer的人
            sendMessage(type: StaticValue.MessageKey.answer, toUser: caller, data: dat)
        case StaticValue.MessageKey.iceCandidate:       // ice
            let data = dic["data"] as! Dictionary<String, Any>
            let user = data["user"] as! String
            
            sendMessage(type: StaticValue.MessageKey.iceCandidate, toUser: user, data: data)
        case StaticValue.MessageKey.name:
            break
        case StaticValue.MessageKey.name:
            break
        default:
            break
        }
        // 循环监听客户端的消息
        for item in bufferPool.values {
            item.readData(withTimeout: -1, tag: 1)
        }
    }
}
// MARK: ^^^^^^^^^^^^^^^ publicMothed ^^^^^^^^^^^^^^^
extension SocketManager {
    /// 断开连接
    public func disConnect() {
        socket?.disconnect()
        socket = nil
    }
    /// 监听
    public func accept(on port: UInt16, success:@escaping () -> Void, fail:@escaping () -> Void) {
        if socket == nil {
            socket = GCDAsyncSocket(delegate: self, delegateQueue: delegateQueue, socketQueue: socketQueue)
        }
        do {
            try socket!.accept(onPort: 8848)
            ht_print(message: "监听成功")
            success()
        } catch let error {
            ht_print(message: "监听失败, error: \(error)")
            fail()
        }
    }
    /// 发送消息到客户端
    private func sendMessage(type: String, toUser user: String, data: Any) {
        if let sock = UsersManager.shared.userSocket[user] {
            sendMessage(type: type, data: data, socket: sock)
        } else {
            ht_print(message: "没有找到'\(user)'对应的socket")
        }
    }
}

