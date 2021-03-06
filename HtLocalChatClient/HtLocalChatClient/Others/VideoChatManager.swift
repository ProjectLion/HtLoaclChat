//
//  VideoChatManager.swift
//  HtLocalChatClient
//
//  Created by Ht on 2019/3/27.
//  Copyright © 2019 Ht. All rights reserved.
//

/*        视频通话的步骤大致分为以下几步:
 *  一、客户端之间在还没有建立P2P连接之前需要通过socket连接服务器来进行通信, 本demo使用CocoaAsyncSocket搭建服务端，并与客户端进行通信。 服务器只负责转发消息，在客户端建立起P2P连接之后数据就不经过服务端处理了。
 *  二、通过socket连接服务端
 *  三、连接成功以后发送用户名(demo做得简陋，就简单的用用户名做唯一值检索了)到服务端，让服务端知道“你是谁”。然后服务端返回当前已连接的用户列表
 *  四、客户端点击tableView上的用户进行通话
 *  五、点击要通话的用户后跳转到视频聊天界面，进行本地视频流的初始化(VideoChatManager.setUp)
 *  六、在收到本地视频流回调后再根据当前用户类型(是主叫还是被叫)做之后的操作
 *
 *  主叫方 caller          被叫方 called
 *  caller： 收到本地视频流回调后发送call方法到服务端，服务端将消息转发给called
 *  called： 收到服务端的call方法后弹窗，询问是否同意进行通话。called同意 -> send(agree) -> 服务端 send(agree) -> caller
 *  caller： 收到agree方法后，进行下面三步(异步进行)
 * * * *caller：使用called的userName创建peerConnection，并添加本地视频流到该连接、添加数据通道(P2P建立成功后使用数据通道进行通信)
 * * * *caller：创建offer。offer创建成功后会将sdp通过block回调出来，将该sdp设置为当前peerConnection的本地描述(serLocalDesc)，然后发送offer方法到服务端。
 * * * *：从STUN服务器获取iceCandidate。在delegate回调里拿到STUN服务器给的iceCandidate，发送iceCandidate方法到服务端。
 *  called：被叫方会收到iceCandidate和offer两个方法：
 * * * *：iceCandidate。使用主叫方的ice信息init一个RTCIceCandidate对象，并将该对象设置添加到当前caller & called之间的peerConnection中
 * * * *：offer。收到offer后用caller的userName创建一个peerConnection，并添加本地视频流到该连接、添加数据通道(P2P建立成功后使用数据通道进行通信)。用caller发送来的sdp描述创建一个offer sdp，设置远程描述。设置完后创建一个answer，answer创建完后同样会回调一个sdp出来，然后设置本地描述(setLocalDesc)，设置完后将answer发送出去(通知caller，answerOffer)
 *  caller：主叫方会收到answerOffer，caller根据called获取连接，创建一个answer RTCSessionDesc，并设置给该连接
 *  至此，caller & called之间已经建立了P2P连接
*/

import UIKit
import WebRTC
import MBProgressHUD

protocol VideoChatManagerDelegate {
    
    /// 设置本地视频流
    ///
    /// - Parameters:
    ///   - manager: 管理对象
    ///   - stream: 视频流
    ///   - id: 用户ID
    func videoChat(manager: VideoChatManager, setLocalStream stream: RTCMediaStream, userID id: String)
    
    /// 添加远程视频流
    ///
    /// - Parameters:
    ///   - manager: 管理对象
    ///   - stream: 视频流
    ///   - id: 用户ID
    func videoChat(manager: VideoChatManager, addRemoteStream stream: RTCMediaStream, userID id: String)
    
    /// 关闭回话回调
    ///
    /// - Parameters:
    ///   - manager: 管理对象
    ///   - id: 用户ID
    func videoChat(manager: VideoChatManager, closeWithUserId id: String)
    
    /// 关闭房间
    ///
    /// - Parameter manager: 管理对象
    func closeRoom(manager: VideoChatManager)
}
/* 拓展协议将方法空实现，实现可选协议方法 */
extension VideoChatManagerDelegate {
    func videoChat(manager: VideoChatManager, setLocalStream stream: RTCMediaStream, userID id: String) {}
    func videoChat(manager: VideoChatManager, addRemoteStream stream: RTCMediaStream, userID id: String) {}
    func videoChat(manager: VideoChatManager, closeWithUserId id: String) {}
    func closeRoom(manager: VideoChatManager) {}
}




/// 视频通话管理类
class VideoChatManager: NSObject {
    /// 单例
    static let shared = VideoChatManager()
    private override init() {
    }
    
    var delegate: VideoChatManagerDelegate!
    
    /// 自己的ID
    private var myID = ""
    /// 存放所有的连接 key: userID
    private var connectionDict: [String: RTCPeerConnection]!
    
    private var connectionIDArr: [String] = []
    /// 连接工厂
    private var factory: RTCPeerConnectionFactory!
    /// 本地视频流
    private var localStream: RTCMediaStream!
    
    private var iceServer: RTCIceServer!
    
}
// MARK: ^^^^^^^^^^^^^^^ Private Method ^^^^^^^^^^^^^^^
extension VideoChatManager {
    
    /// 添加socket回调监听
    private func addSocketObservers() {
        
        // 添加监听 event: 需要监听的事件(服务器的数据key值)
        SocketManager.shared.on = {
            switch $0 {
            case StaticValue.MessageKey.agree:    // 1. 同意通话 去获取SDP创建offer
                self.agree(data: $1 as! [String])
            case StaticValue.MessageKey.leaveRoom:        // 2. 有人离开房间
                self.leaveRoom(data: $1 as! String)
            case StaticValue.MessageKey.iceCandidate:     // 3. 新加入的人发了ICE候选
                self.iceCandidate(data: $1 as! Dictionary<String, Any>)
            case StaticValue.MessageKey.newPeer:           // 4. 有新人员加入
                self.newPeer(data: $1 as! String)
            case StaticValue.MessageKey.offer:                // 5. 新加入的人发了offer
                self.offer(data: $1 as! Dictionary<String, Any>)
            case StaticValue.MessageKey.answerOffer:      // 6. 回应offer
                self.answerOffer(data: $1 as! Dictionary<String, Any>)
            case StaticValue.MessageKey.refuseChat:        // 7. 拒绝通话
                self.refuseChat(data: $1 as! Dictionary<String, Any>)
            case StaticValue.MessageKey.none:
                break
            default:
                break
            }
        }
    }
    
    /// 创建本地视频流
    private func creatLocalStream() {
        
        if factory == nil {
            factory = RTCPeerConnectionFactory()
        }
        localStream = factory.mediaStream(withStreamId: "ARDAMS")
        
        HTPrivatePermission.getAudioPermission { (isHave) in
            if isHave {
                // 音频追踪
                let audioTrack = self.factory.audioTrack(withTrackId: "ARDAMSa0")
                audioTrack.source.volume = 5
                self.localStream.addAudioTrack(audioTrack)
            } else {
                MBProgressHUD.ht_show(text: "没有麦克风权限", inView: UIApplication.shared.keyWindow!)
            }
        }
        
        HTPrivatePermission.getVideoPermission { (isHave) in
            if isHave {
                let videoSource = self.factory.avFoundationVideoSource(with: self.localVideoConstraints())
                videoSource.captureSession.outputs.first!.connections.first!.isVideoMirrored = true
                // 切换瑟像头
                //                videoSource.useBackCamera = true
                let videoTrack = self.factory.videoTrack(with: videoSource, trackId: "ARDAMSv0")        // RTCVideoTrack
                ht_print(message: "摄像头状态: \(videoTrack.readyState)")
                self.localStream.addVideoTrack(videoTrack)
                // 将设置好的视频流回调出去
                self.delegate.videoChat(manager: self, setLocalStream: self.localStream, userID: self.myID)
            } else {
                MBProgressHUD.ht_show(text: "没有相机权限", inView: UIApplication.shared.keyWindow!)
            }
        }
        
    }
    /// 视频约束
    private func localVideoConstraints() -> RTCMediaConstraints {
        let constraints = RTCMediaConstraints(mandatoryConstraints: [kRTCMediaConstraintsMaxWidth: "640", kRTCMediaConstraintsMinWidth: "640", kRTCMediaConstraintsMaxHeight: "480", kRTCMediaConstraintsMinHeight: "480", kRTCMediaConstraintsMinFrameRate: "15"], optionalConstraints: nil)
        return constraints
    }
    
    /// 根据内存中的ID创建连接
    private func createPeerConnections() {
        for item in connectionIDArr {       // 遍历id，根据id创建连接
            if item != UserDefaults.standard.string(forKey: "name")! {
                let connection = creatPeerConnection(id: item)
                creatOffer(connection: connection, id: item)
            }
        }
    }
    
    /// 根据ID创建点对点连接（同时发送包含sdp的offer 和 从STUN服务器获取ice candidate）
    ///
    /// - Parameter id: 连接ID
    @discardableResult private func creatPeerConnection(id: String) -> RTCPeerConnection {
        
        if iceServer == nil {
            iceServer = RTCIceServer(urlStrings: ["turn:115.28.170.217:3478"], username: "zmecust", credential: "zmecust")
        }
        if factory == nil {
            factory = RTCPeerConnectionFactory()
        }
        let configuration = RTCConfiguration()
        configuration.iceServers = [iceServer]
        
        let mediaConstraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: ["DtlsSrtpKeyAgreement" : "true"])
        // 在回调里(RTCPeerConnectionDelegate)发送ice candidate给服务器
        let connection = factory.peerConnection(with: configuration, constraints: mediaConstraints, delegate: self)
        // 为所有连接添加上流（其实就是将本地的视频流发出去，让别人接收，会触发didAdd stream）
        if localStream == nil {
            creatLocalStream()
        }
        connection.add(localStream)
        // 创建数据通道
        let dataChannelConfig = RTCDataChannelConfiguration()
        let dataChannel = connection.dataChannel(forLabel: "htDataChannel", configuration: dataChannelConfig)
        dataChannel.delegate = self
        connectionDict[id] = connection     // 将创建好的连接保存起来
        connectionIDArr.append(id)
        return connection
    }
    
    /// 创建offer
    private func creatOffer(connection: RTCPeerConnection, id: String) {
        ht_print(message: "创建offer,当前信令状态为: \(connection.signalingState.rawValue)")
        // 为点对点连接创建offer
        connection.offer(for: creatMeidaConstraint()) {
            // $0: sessionDesc   $1: error
            if $1 == nil {       // 创建完SDP时，将创建好的SDP通过socket发送给服务器
                ht_print(message: "创建完offer,当前信令状态为: \(connection.signalingState.rawValue)")
                if let sdp = $0 {
                    // 创建本地sdp
                    connection.setLocalDescription(sdp, completionHandler: { (error) in
                        if error == nil {
                            ht_print(message: "setRemoteDesc,当前信令状态为: \(connection.signalingState.rawValue)")
                            //  发送sdp到服务器 即发送offer给called
                            let dict: [String : Any] = ["sdp": sdp.sdp, "caller": UserDefaults.standard.string(forKey: "name")!, "called": id]
                            SocketManager.shared.sendMessage(type: StaticValue.MessageKey.offer, data: dict)
                        }
                    })
                }
            }
        }
    }
    
    /// 创建offer/answer约束
    ///
    /// - Returns: 约束
    @discardableResult private func creatMeidaConstraint() -> RTCMediaConstraints {
        let result = RTCMediaConstraints(mandatoryConstraints: [kRTCMediaConstraintsOfferToReceiveAudio:kRTCMediaConstraintsValueTrue,kRTCMediaConstraintsOfferToReceiveVideo:kRTCMediaConstraintsValueTrue], optionalConstraints: nil)
        return result
    }
    /// 创建数据通道
    private func creatDataChannel(forPeerConnection peerConnection: RTCPeerConnection) {
        let config = RTCDataChannelConfiguration()
        config.isOrdered = true
        peerConnection.dataChannel(forLabel: "dd", configuration: config)
        
    }
    
    /// 关闭连接
    ///
    /// - Parameter connectionID: 连接ID
    private func close(connectionID: String) {
        guard let connection = connectionDict[connectionID] else { return }
        connection.close()
        connectionIDArr.removeAll(where: {$0 == connectionID} )
        connectionDict.removeValue(forKey: connectionID)
        DispatchQueue.main.async {
            self.delegate.videoChat(manager: self, closeWithUserId: connectionID)
        }
    }
    
}

// MARK: ^^^^^^^^^^^^^^^ obsever mothed ^^^^^^^^^^^^^^^
extension VideoChatManager {
    /// agree
    private func agree(data: [String]) {
        
        connectionIDArr.append(contentsOf: data)
        
        //        myID = data["id"] as! String       // 取到服务器给自己分配的ID
        // 创建连接
        createPeerConnections()
    }
    
    /// 有人离开房间
    private func leaveRoom(data: String) {
        
        let peerConnection = connectionDict[data]
        peerConnection?.close()
        connectionDict.removeValue(forKey: data)
        connectionIDArr.removeAll {
            $0 == data
        }
        DispatchQueue.main.async {
            self.delegate.videoChat(manager: self, closeWithUserId: data)
            if self.connectionIDArr.isEmpty {       // 没有连接的人后关闭房间
                self.delegate.closeRoom(manager: self)
            } else {
                self.delegate.videoChat(manager: self, closeWithUserId: data)
            }
        }
    }
    
    /// 新加入的人发了ICE候选
    private func iceCandidate(data: Dictionary<String, Any>) {
        let peerConnectionID = data["user"] as! String
        let sdpMid = data["id"] as! String
        let sdpMLineIndex = data["label"] as! Int32
        let candiateStr = data["candiate"] as! String
        // 生成远端网络地址对象
        let candiate = RTCIceCandidate(sdp: candiateStr, sdpMLineIndex: sdpMLineIndex, sdpMid: sdpMid)
        // 根据ID拿到当前的点对点连接
        let peerConnection = connectionDict[peerConnectionID]
        // 将网络地址对象添加到点对点连接中
        peerConnection?.add(candiate)
    }
    
    /// 有新人加入。服务器说: "有新的客人来了"
    /// 然后客户端化妆()、铺地毯(建立连接)、自报家门(发送sdp、ice candidate)，为了和客人进一步交流
    private func newPeer(data: String) {
        // 根据ID创建点对点连接
        // 在创建连接时已经将包含sdp的offer和ice candidate发送出去了
        let peerConnection = creatPeerConnection(id: data)
        creatOffer(connection: peerConnection, id: data)
    }
    
    /// 收到其他人的offer (收到offer表示自己是被叫方)
    private func offer(data: Dictionary<String, Any>) {
        let sdp = data["sdp"] as! String
        let caller = data["caller"] as! String
        // 用主叫方的id创建一个连接
        let peerConnection = creatPeerConnection(id: caller)
        
        // 创建一个远程sdp
        let remoteSDP = RTCSessionDescription(type: .offer, sdp: sdp)
        peerConnection.setRemoteDescription(remoteSDP) { (error) in
            if error == nil {
                peerConnection.answer(for: self.creatMeidaConstraint(), completionHandler: { (sdp, error) in
                    if error == nil {
                        peerConnection.setLocalDescription(sdp!, completionHandler: {
                            if $0 == nil {
                                // 发送answer
                                let dict: [String : Any] = ["type": sdp!.type.rawValue, "sdp": sdp!.sdp, "caller": caller, "called": UserDefaults.standard.string(forKey: "name")!]
                                SocketManager.shared.sendMessage(type: StaticValue.MessageKey.answerOffer, data: dict)
                            }
                        })
                    }
                })
            } else {
                ht_print(message: error)
            }
        }
    }
    
    /// 收到answer(收到answerOffer后保存sdp，也就是setRemoteSDP)
    private func answerOffer(data: Dictionary<String, Any>) {
        let sdp = data["sdp"] as! String
        let called = data["called"] as! String
        let peerConnection = connectionDict[called]
        let remoteSDP = RTCSessionDescription(type: .answer, sdp: sdp)
        peerConnection?.setRemoteDescription(remoteSDP, completionHandler: { (error) in
            
        })
    }
    
    /// 拒绝通话
    private func refuseChat(data: Dictionary<String, Any>) {
        delegate.closeRoom(manager: self)
    }
    
}

// MARK: ^^^^^^^^^^^^^^^ Public Method ^^^^^^^^^^^^^^^
extension VideoChatManager {
    /// 初始化，为视频通话做准备
    public func setUp() {
        // 初始化连接池
        if connectionDict == nil {
            connectionDict = Dictionary<String, RTCPeerConnection>()
        }
        // 初始化工厂，WebRTC使用的工厂模式进行其他类的实例化
        if factory == nil {
            factory = RTCPeerConnectionFactory()
        }
        // 初始化本地视频流（在接收到本地视频流回调后再进行后面的步骤，eg: call、agree...）
        if localStream == nil {
            creatLocalStream()
        }
        // 添加socket回调监听
        addSocketObservers()
    }
    
    /// 退出房间
    public func exitRoom(forUser user: String) {
        if connectionIDArr.count < 2 {     // 当房间内人数小于2人时，关闭房间
            SocketManager.shared.sendMessage(type: StaticValue.MessageKey.closeRoom, data: ["": ""])
        } else {
            SocketManager.shared.sendMessage(type: StaticValue.MessageKey.leaveRoom, data: ["": ""])
        }
        //        close(connectionID: connectionID)
        factory = nil
        localStream = nil
    }
}

// MARK: ^^^^^^^^^^^^^^^ RTCPeerConnectionDelegate ^^^^^^^^^^^^^^^
extension VideoChatManager: RTCPeerConnectionDelegate {       // 连接代理
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        ht_print(message: "信令通道状态改变status: \(stateChanged.rawValue)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        ht_print(message: "接收到新的视频流")
        DispatchQueue.main.async {
            self.delegate.videoChat(manager: self, addRemoteStream: stream, userID: self.connectionDict.key(withValue: peerConnection) ?? "")
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        ht_print(message: "远方的她关闭视频流")
    }
    
    // 从ICE Server获取iceCandidate，然后发送给服务器
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        if let id = connectionDict.key(withValue: peerConnection) {
            let dict: [String: Any] = ["id": candidate.sdpMid ?? "", "label": candidate.sdpMLineIndex, "candidate": candidate.sdp, "user": id]
//            SocketManager.shared.sendMessage(type: StaticValue.MessageKey.iceCandidate, data: dict)
        } else {
            ht_print(message: "获取内存中的连接失败请检查; \(connectionDict ?? [:])")
        }
    }
    
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        ht_print(message: "连接状态改变")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        ht_print(message: "打开数据通道")
    }
    
    
}

extension VideoChatManager: RTCDataChannelDelegate {
    func dataChannelDidChangeState(_ dataChannel: RTCDataChannel) {
        ht_print(message: "数据通道状态改变; \(dataChannel.readyState.rawValue)")
    }
    
    func dataChannel(_ dataChannel: RTCDataChannel, didReceiveMessageWith buffer: RTCDataBuffer) {
        ht_print(message: "数据通道收到消息; \(String(data: buffer.data, encoding: .utf8))")
    }
    
    
}

extension Dictionary {
    
    /// 根据value查找key
    ///
    /// - Parameter value: value
    /// - Returns: key
    func key(withValue value: RTCPeerConnection) -> String? {
        for item in (self as! Dictionary<String, RTCPeerConnection>).enumerated() {
            if value == item.element.value {
                return item.element.key
            }
        }
        return nil
    }
}

