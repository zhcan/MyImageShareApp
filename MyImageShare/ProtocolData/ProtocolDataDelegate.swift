//
//  ProtocolDataDelegate.swift
//  MyImageShare
//
//  Created by 陈婷婷 on 2022/10/22.
//

import Foundation

public protocol ProtocolDataDelegate: NSObjectProtocol {
    func onSingleFileComplete(path: String)
}
