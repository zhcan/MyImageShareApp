//
//  SocketManagerDelegate.swift
//  MyImageShare
//
//  Created by 陈婷婷 on 2022/10/21.
//

import Foundation

public protocol SocketManagerDelegate: NSObjectProtocol {
    func socketConnected()
    
    func socketDisconnect()
    
    func ImageSaved(path: String)
}
