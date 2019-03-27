//
//  SocketManager.swift
//  HtLocalChatClient
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
    
    public var apiRoot = "http://192.168.2.162"
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
    
    /// socket
    private var socket: GCDAsyncSocket?
    /// 监听
    var on: (_ messageKey: String, _ data: Any) -> Void = { _,_ in }
}

extension SocketManager: GCDAsyncSocketDelegate {
    // 收到新的socket连接时的回调
    func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        ht_print(message: "连接成功")
        // 将自己的name发送给服务器
        sendMessage(type: StaticValue.MessageKey.name, data: UserDefaults.standard.string(forKey: "name")!)
        on(StaticValue.MessageKey.connected, "connected")
        // 连接成功后就开始读取(其实就是监听)服务器的消息
        sock.readData(withTimeout: -1, tag: 1)
    }
    
    /// readData(withTimeout: Int, tag: Int) 的回调
    func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
        // 包头(包头包含了正文的数据长度)
//        let headData = data.subdata(in: 0..<4)
        // 正文length
//        let strLength = dataToInt(withData: headData)
        let desc = String(data: data, encoding: .utf8)
        ht_print(message: "正文: \(desc!)")
        let dict = try! JSONSerialization.jsonObject(with: data, options: .allowFragments) as? Dictionary<String, Any>
        if let dic = dict {
            DispatchQueue.main.async {
                self.on(dic["type"] as! String, dic["data"]!)
            }
        }
        // 监听服务器的消息
        socket!.readData(withTimeout: -1, tag: 1)
    }
    /// 发送消息给服务端
    ///
    /// - Parameters:
    ///   - type: 消息类型
    ///   - data: 想要发送的数据
    ///   - socket: socket
    public func sendMessage(type: String, data: Any) {
        let data = dictToString(dict: ["type": type, "data": data]).data(using: .utf8)
//        var intData = intToData(withValue: data!.count)
//        intData.append(data!)
        socket?.write(data!, withTimeout: -1, tag: 0)
    }
}
// MARK: ^^^^^^^^^^^^^^^ publicMothed ^^^^^^^^^^^^^^^
extension SocketManager {
    /// 断开连接
    public func disConnect() {
        socket?.disconnect()
    }
    /// 连接
    public func connct(to port: UInt16) {
        if socket == nil {
            socket = GCDAsyncSocket(delegate: self, delegateQueue: delegateQueue, socketQueue: socketQueue)
        }
        do {
            try socket!.connect(toHost: "192.168.2.247", onPort: 8848)
        } catch let error {
            ht_print(message: "连接失败, error: \(error)")
        }
    }
    
//    /// 发送消息到服务器
//    ///
//    /// - Parameter data: 要发送的json字符串
//    public func sendMessage(dict: Dictionary<String, Any>) {
//        let data = dictToString(dict: dict).data(using: .utf8)
//        var intData = intToData(withValue: data!.count)
//        intData.append(data!)
//        socket?.write(intData, withTimeout: -1, tag: 0)
//    }
}


