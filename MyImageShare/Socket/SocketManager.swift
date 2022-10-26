//
//  SocketManager.swift
//  MyImageShare
//
//  Created by 陈婷婷 on 2022/10/21.
//

import Foundation
import CocoaAsyncSocket

class SocketManager: NSObject {
    static let shared = SocketManager()
    
    weak var delegate: SocketManagerDelegate?

    var serverPort: UInt16 = 0
    var serverIp: String = "0.0.0.0"
    var diction: NSDictionary?
    var clientSocket: GCDAsyncSocket!

    fileprivate var timer: Timer?
    
    // 0: disconnected, 1: connecting, 2: connected
    private var connectionState : SocketState = .idle
    
    private override init() {
        super.init()
        self.timer = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(timerAction), userInfo: nil, repeats: true)
        RunLoop.main.add(timer!, forMode: RunLoop.Mode.common)
        self.timer?.fireDate = Date.distantFuture
    }
    
    @objc func timerAction() -> Void {
        // send data to keep alive
    }
    
    func destroyTimer() {
        self.timer?.invalidate()
        self.timer = nil
    }
    
    func initIpPort(ip: String, port: UInt16) {
        print("set ip:\(ip), port:\(port)")
        self.serverIp = ip
        self.serverPort = port
    }

    func connectServer() {
        print("try connect \(serverIp):\(serverPort)")
        
        if (connectionState != .idle) {
            print("already connected. stop last session")
            clientSocket.disconnect()
        }
        
        clientSocket = GCDAsyncSocket()
        clientSocket.delegate = self
        clientSocket.delegateQueue = DispatchQueue.global()
        do {
            connectionState = .connecting
            try clientSocket.connect(toHost: serverIp, onPort: serverPort)
        } catch {
            print("try connect error: \(error)")
            connectionState = .idle
        }
    }
    
    func disconnectServer() {
        clientSocket?.disconnect()
        
        connectionState = .idle
    }
    
    func sendImage(image : UIImage, name: String) -> Bool {
        guard connectionState == .connected else {
            print("sendImage socket not ready!")
            return false
        }
        print("sendImage")
        if let sendData = ProtocolData.packageImg(image: image, fileName: name) {
            clientSocket.write(sendData, withTimeout: -1, tag: 0)
            print("send data \(NSData(data: sendData))")
            return true
        }
        
        print("send img fail!")
        return false
    }
    
    func sendMessage(_ serviceDic:[String : Any]?) {
        guard connectionState == .connected else {
            print("sendMessage socket not ready!")
            return
        }
        
        print("send message begin")
        var bodyDatas = Data()
        if serviceDic != nil {
            bodyDatas = try! JSONSerialization.data(withJSONObject: serviceDic!, options: .prettyPrinted)
        } else {
            bodyDatas.count = 4
        }
        
        print("send message \(bodyDatas)")
        clientSocket.write(bodyDatas, withTimeout: -1, tag: 0)
    }
}

extension SocketManager: GCDAsyncSocketDelegate {
    func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        print("connect to host success.")
        connectionState = .connected
        self.delegate?.socketConnected()
        
        ProtocolData.waitHeadData(sock)
    }
    
    func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        print("Socket connect fail: \(String(describing: err))")
        connectionState = .idle
        self.delegate?.socketDisconnect()
    }
    
    func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
        print("Data recieved....")
        
        if (ProtocolData.reader == nil) {
            print("recieve head data.")
            ProtocolData.reader = ProtocolDataReader()
            ProtocolData.reader!.delegate = self
            if (!ProtocolData.reader!.readHeadData(rawData: data)) {
                print("read head data error!")
                
                ProtocolData.reader = nil
                // 丢弃，读下一个数据头
                ProtocolData.waitHeadData( sock)
            } else {
                // 开始读文件数据
                ProtocolData.reader!.startReadFile(sock: sock)
            }
            
            return
        }
        
        print("SocketManager read file data")
        let result = ProtocolData.reader!.readFileData(sock: sock, rawData: data, tag: tag)
        
        if (!result) {
            print("Data read ERROR!")
            ProtocolData.reader = nil
            ProtocolData.waitHeadData(sock)
        }
    }
}

extension SocketManager: ProtocolDataDelegate {
    func onSingleFileComplete(path: String) {
        // 默认是图片文件
        self.delegate?.ImageSaved(path: path)
        ProtocolData.reader = nil
    }
}
extension SocketManager {
    public enum SocketState {
        case idle
        
        case connecting
        
        case connected
    }
}
