//
//  ProtocolDataReader.swift
//  MyImageShare
//
//  Created by 陈婷婷 on 2022/10/22.
//

import Foundation
import CocoaAsyncSocket

class ProtocolDataReader : NSObject {
    static let TAG_READ_FILENAME_TYPE = 1
    static let TAG_READ_FILENAME_LEN = 2
    static let TAG_READ_FILENAME = 3
    static let TAG_READ_FILEDATA_TYPE_AND_LEN = 4
    static let TAG_READ_FILE_LEN = 5
    static let TAG_READ_FILEDATA = 6
    
    // 文件数量长度
    var fileCountType : UInt8 = 0
    // 文件数量
    var fileCount : UInt32 = 0
    // 文件大小长度
    var fileTotalLenType : UInt8 = 0
    // 文件总大小
    var fileTotalLen : UInt64 = 0

    var fileReader : SingleFileReader?
    
    var recievedFileCount : UInt32 = 0
    var recievedTotalLen : UInt64 = 0
    
    weak var delegate: ProtocolDataDelegate?
    
    override init() {
        fileCountType = 0
        fileCount = 0
        fileTotalLenType = 0
        fileTotalLen = 0
        
        recievedFileCount = 0
        recievedTotalLen = 0
    }
    
    class func waitHeadData(_ sock: GCDAsyncSocket) {
        sock.readData(toLength: ProtocolData.getPkgHeadLenBytes(), withTimeout: -1, tag: 0)
    }
    
    func readHeadData(rawData: Data) -> Bool {
        var currentPos : Int = 0
        
        if (rawData.count != (ProtocolData.typeValueCountType + ProtocolData.fileCountBytes + ProtocolData.fileTotalLenTypeBytes + ProtocolData.fileTotalLenBytes)) {
            print("error head data len:\(rawData.count)")
            return false
        }
        rawData.copyBytes(to: &fileCountType, from: (currentPos..<ProtocolData.fileCountTypeBytes))
        currentPos += ProtocolData.fileCountTypeBytes
        
        if (fileCountType != ProtocolData.typeValueCountType) {
            print("error countType: \(fileCountType)")
            return false
        }
        
        fileCount = ReadUtil.readUint32(data: rawData, range: (currentPos..<(currentPos + ProtocolData.fileCountBytes)))
        currentPos += ProtocolData.fileCountBytes
        
        rawData.copyBytes(to: &fileTotalLenType, from: (currentPos..<(currentPos + ProtocolData.fileTotalLenTypeBytes)))
        currentPos += ProtocolData.fileTotalLenTypeBytes

        if (fileTotalLenType != ProtocolData.typeValueTotalLenType) {
            print("error total len type: \(fileTotalLenType)")
            return false
        }
        
        fileTotalLen = ReadUtil.readUint64(data: rawData, range: (currentPos..<(currentPos + ProtocolData.fileTotalLenBytes)))
        currentPos += ProtocolData.fileTotalLenBytes
        
        print("read head data success. fileCountType:\(fileCountType), fileCount:\(fileCount), fileTotalLenType:\(fileTotalLenType), fileTotalLen:\(fileTotalLen)")
        
        return true
    }
    
    func startReadFile(sock: GCDAsyncSocket) {
        if (fileReader != nil) {
            print("start read file error, already start reading.")
            return
        }
        
        fileReader = SingleFileReader()
        // 等待读文件名类型
        sock.readData(toLength: UInt(ProtocolData.fileNameTypeBytes), withTimeout: -1, tag: ProtocolDataReader.TAG_READ_FILENAME_TYPE)
    }
    
    func readFileData(sock: GCDAsyncSocket, rawData: Data, tag: Int) -> Bool {
        var result = false
        switch tag {
        case ProtocolDataReader.TAG_READ_FILENAME_TYPE:
            print("read file name type")
            result = fileReader!.readFileNameType(rawData: rawData)
            // 等待filenamelen
            sock.readData(toLength: UInt(ProtocolData.fileNameLenBytes), withTimeout: -1, tag: ProtocolDataReader.TAG_READ_FILENAME_LEN)
            
        case ProtocolDataReader.TAG_READ_FILENAME_LEN:
            print("read file name len")
            result = fileReader!.readFileNameLen(rawData: rawData)
            // 等待filename
            sock.readData(toLength: UInt(fileReader!.fileNameLen), withTimeout: -1, tag: ProtocolDataReader.TAG_READ_FILENAME)
            
        case ProtocolDataReader.TAG_READ_FILENAME:
            print("read file name")
            result = fileReader!.readFileName(rawData: rawData)
            // 等待filedatatype
            sock.readData(toLength: UInt(ProtocolData.fileDataTypeBytes + ProtocolData.fileLenBytes), withTimeout: -1, tag: ProtocolDataReader.TAG_READ_FILEDATA_TYPE_AND_LEN)
            
        case ProtocolDataReader.TAG_READ_FILEDATA_TYPE_AND_LEN:
            print("read file data type and len")
            result = fileReader!.readFileDataTypeAndLen(rawData: rawData)
//            // 等待filelen
//            sock.readData(toLength: UInt(ProtocolData.fileLenBytes), withTimeout: -1, tag: ProtocolDataReader.TAG_READ_FILE_LEN)
//
//        case ProtocolDataReader.TAG_READ_FILE_LEN:
//            print("read file len")
//            result = fileReader!.readFileLen(rawData: rawData)
            // 等待file data
            sock.readData(toLength: UInt(fileReader!.getFileDataReadLen()), withTimeout: -1, tag: ProtocolDataReader.TAG_READ_FILEDATA)
            
        case ProtocolDataReader.TAG_READ_FILEDATA:
            print("read file data")
            result = fileReader!.readFileData(rawData: rawData)
            
            if result {
                if (fileReader!.getFileDataReadLen() <= 0) {
                    recievedFileCount += 1
                    
                    // todo: 回调给业务
                    delegate?.onSingleFileComplete(path: (fileReader!.filePath)!)
                    fileReader = nil
                    
                    if (recievedFileCount >= fileCount) {
                        // 文件发送完毕，等待下次发起
                        ProtocolDataReader.waitHeadData(sock)
                    }  else {
                        // 读取下一个文件
                        startReadFile(sock: sock)
                    }
                } else {
                    // 等待file data
                    sock.readData(toLength: UInt(fileReader!.getFileDataReadLen()), withTimeout: -1, tag: ProtocolDataReader.TAG_READ_FILEDATA)
                }
            }
        default: break
        }
        
    
        return result
    }
    

}

extension ProtocolDataReader {
    class SingleFileReader {
        static let BUFFER_SIZE : UInt64 = 1024 * 8

        // 文件名类型
        var fileNameType : UInt8 = 0
        // 文件名长度
        var fileNameLen : UInt16 = 0
        // 文件名（长度不定）
        var fileName : String = ""
        // 文件数据类型
        var fileDataType : UInt8 = 0
        // 文件大小
        var fileLen : UInt64 = 0
        
        var currentPos : Int = 0
        
        var remainDataLen : UInt64 = 0

        var filePath : String?
        var image : UIImage?
        
        init() {
        }
        
        func readFileNameType(rawData: Data) -> Bool {
            rawData.copyBytes(to: &fileNameType, count: 1)
            if (fileNameType != ProtocolData.typeValueFileNameType) {
                print("error name type \(fileNameType)")
                return false
            }
            
            print("fileNameType: \(fileNameType)")
            return true
        }
        
        func readFileNameLen(rawData: Data) -> Bool  {
            fileNameLen = ReadUtil.readUint16(data: rawData, range: (0..<2))
            
            print("fileNameLen: \(fileNameLen)")
            return true
        }
        
        // 默认文件名不会超过缓冲区长度
        func readFileName(rawData: Data) -> Bool  {
            print("start read file name. len: \(rawData.count)")
            var tmpArray : [UInt8] = [UInt8](repeating: 0, count: rawData.count)
            rawData.copyBytes(to: &tmpArray, count: rawData.count)
            fileName = String(bytes: tmpArray, encoding: .utf8)! // String(data: rawData, encoding: String.Encoding.utf8)!
            print("read filename: \(fileName)")
            return true
        }
        
        func readFileDataType(rawData: Data) -> Bool  {
            rawData.copyBytes(to: &fileDataType, count: 1)
            if (fileDataType != ProtocolData.typeValueFileDataType) {
                print("error data type \(fileDataType)")
                return false
            }
            return true
        }
        
        func readFileLen(rawData: Data) -> Bool  {
            fileLen = ReadUtil.readUint64(data: rawData, range: (0..<8))
            remainDataLen = fileLen
            return true
        }
        
        func readFileDataTypeAndLen(rawData: Data) -> Bool  {
            rawData.copyBytes(to: &fileDataType, count: ProtocolData.fileDataTypeBytes)
            if (fileDataType != ProtocolData.typeValueFileDataType) {
                print("error data type \(fileDataType)")
                return false
            }
            
            fileLen = ReadUtil.readUint64(data: rawData, range: (ProtocolData.fileDataTypeBytes..<(ProtocolData.fileDataTypeBytes + ProtocolData.fileLenBytes)))
            remainDataLen = fileLen
            print("read file len:\(fileLen)")
            return true
        }
        
        func readFileData(rawData: Data) -> Bool  {
            print("read file data. len: \(rawData.count), remain: \(remainDataLen)")
            remainDataLen -= UInt64(rawData.count)
            
            if filePath == nil {
                filePath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] + "/" + fileName
                print("try to create file:\(String(describing: filePath))")
                if (FileManager.default.fileExists(atPath: filePath!)) {
                    do {
                        try FileManager.default.removeItem(atPath: filePath!)
                    } catch let error {
                        print("remove file error \(error)")
                    }
                }
                
                let creatRet = FileManager.default.createFile(atPath: filePath!, contents: nil)
                if (!creatRet) {
                    print("create file fail!")
                    return false
                }
                
                print("create file sucess. path:\(String(describing: filePath))")
            }
            
            return writeImage(rawData)
        }
        
        private func writeImage(_ data: Data) -> Bool {
            let fileHandle = FileHandle(forWritingAtPath: filePath!)!
            fileHandle.seekToEndOfFile()
            
            var result = false
            do {
                try fileHandle.write(contentsOf: data)
                result = true
            } catch let error {
                print("write file error. \(error)")
                result = false
            }
            try? fileHandle.close()
            
            return result
        }
        
        func getFileDataReadLen() -> UInt64 {
            return remainDataLen > SingleFileReader.BUFFER_SIZE ? SingleFileReader.BUFFER_SIZE : remainDataLen
        }
    }
}

extension ProtocolDataReader {
    class ReadUtil {
        private class func readUint<T : FixedWidthInteger>(data: Data!, range : Range<Data.Index>) -> T {
            var tmpArray : [UInt8] = [UInt8](repeating: 0, count: MemoryLayout<T>.stride)
            data.copyBytes(to: &tmpArray, from: range)

            var result : T = 0
            let len = tmpArray.count
            for (index, value) in tmpArray.enumerated() {
                result += ((T)(value) << ((len - index - 1) * 8))
            }
            return result
            
            
        }
        
        class func readUint64(data: Data!, range : Range<Data.Index>) -> UInt64 {
            let ret : UInt64 = readUint(data: data, range: range)
            return ret
        }
        
        class func readUint32(data: Data!, range : Range<Data.Index>) -> UInt32 {
            let ret : UInt32 = readUint(data: data, range: range)
            return ret
        }
        
        class func readUint16(data: Data!, range : Range<Data.Index>) -> UInt16 {
            let ret : UInt16 = readUint(data: data, range: range)
            return ret
        }
    }
}
