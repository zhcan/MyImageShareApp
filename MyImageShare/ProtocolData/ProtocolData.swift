//
//  ProtocolData.swift
//  MyImageShare
//
//  Created by 陈婷婷 on 2022/10/22.
//

import Foundation
import UIKit
import CocoaAsyncSocket

class ProtocolData: NSObject {
    static let versionByes : Int = 2
    
    // Head begin
    // 文件数量类型长度
    static let fileCountTypeBytes : Int = 1
    // 文件数量
    static let fileCountBytes : Int = 4
    // 文件大小长度
    static let fileTotalLenTypeBytes : Int = 1
    // 文件总大小
    static let fileTotalLenBytes : Int = 8
    // Head end
    
    // 文件名类型
    static let fileNameTypeBytes : Int = 1
    // 文件名长度
    static let fileNameLenBytes : Int = 2
    // 文件名（长度不定）
    // 文件数据类型
    static let fileDataTypeBytes : Int = 1
    // 文件大小
    static let fileLenBytes : Int = 8
    // 文件数据（长度不定）
    
    // MARK: 数据类型
    // 文件数量类型
    static let typeValueCountType = 1
    // 文件总大小类型
    static let typeValueTotalLenType = 2
    // 单个文件名类型
    static let typeValueFileNameType = 16
    // 单个文件大小类型
    static let typeValueFileDataType = 17

    static var reader : ProtocolDataReader?

    class func getPkgHeadLenBytes() -> UInt {
        return (UInt)(fileCountTypeBytes + fileCountBytes + fileTotalLenTypeBytes + fileTotalLenBytes)
    }
    
    class func packageImg(image: UIImage, fileName:String) -> Data? {
        if let imgData = image.pngData() {
            var bodyDatas = Data()
            let imgLength = UInt64(imgData.count)
            
            let imgName = fileName + ".png"
            let nameLen = imgName.lengthOfBytes(using: String.Encoding.utf8)
            print("send imgName:\(imgName), nameLen:\(nameLen), id:\(String(describing: image.accessibilityIdentifier))")
            
            bodyDatas.append(packageFileCountType(type: typeValueCountType))
            bodyDatas.append(packageFileCount(fileCount: 1))  // 目前只传一张图片
            bodyDatas.append(packageFileTotalLenType(type: typeValueTotalLenType))
            bodyDatas.append(packageFileTotalLen(len: imgLength))
            bodyDatas.append(packageFileNameType(type: typeValueFileNameType))
            bodyDatas.append(packageFileNameLen(len: nameLen))
            bodyDatas.append(packageFileName(name: imgName))
            bodyDatas.append(packageFileDataType(type: typeValueFileDataType))
            bodyDatas.append(packageFileLen(len: imgLength))
            // printData(data: bodyDatas)
            bodyDatas.append(imgData)
            
            return bodyDatas
        } else {
            print("package image data error")
            return nil
        }
    }
    
    class func waitHeadData(_ sock: GCDAsyncSocket) {
        ProtocolDataReader.waitHeadData(sock)
    }
    
    private class func packageData<T>(_ data: T, dataBytes : Int) -> Data! {
        var tmpData = data
        return Data(bytes: &tmpData, count: dataBytes)
    }
    
    private class func packageFileCountType(type : Int) -> Data! {
        return packageData(type, dataBytes: ProtocolData.fileCountTypeBytes)
    }
    
    private class func packageFileCount(fileCount : Int) -> Data! {
        return packageData(fileCount, dataBytes: ProtocolData.fileCountBytes)
    }
    
    private class func packageFileTotalLenType(type : Int) -> Data! {
        return packageData(type, dataBytes: ProtocolData.fileTotalLenTypeBytes)
    }
    
    private class func packageFileTotalLen(len : UInt64) -> Data! {
        return packageData(len, dataBytes: ProtocolData.fileTotalLenBytes)
    }
    
    private class func packageFileNameType(type : Int) -> Data! {
        return packageData(type, dataBytes: ProtocolData.fileNameTypeBytes)
    }
    
    private class func packageFileNameLen(len : Int) -> Data! {
        return packageData(len, dataBytes: ProtocolData.fileNameLenBytes)
    }
    
    private class func packageFileName(name : String) -> Data! {
        let nameData = name.data(using: .utf8)
        printData(data: nameData)
        return nameData
    }
    
    private class func packageFileDataType(type : Int) -> Data! {
        return packageData(type, dataBytes: ProtocolData.fileDataTypeBytes)
    }
    
    private class func packageFileLen(len : UInt64) -> Data! {
        return packageData(len, dataBytes: ProtocolData.fileLenBytes)
    }
    
    private class func printData(data: Data!) {
        let dataString = data.map { String(format: "%02x", $0)}.joined(separator: " ")
        print("data: \(dataString)")
    }
}
