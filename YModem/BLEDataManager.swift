//
//  BLEDataManager.swift
//  YModem
//
//  Created by Zayata on 26/03/2020.
//  Copyright © 2020 Lynx. All rights reserved.
//

import UIKit

///设备发送的C包的类型
enum OTACType {
    case start  //起始包
    case main   //发送主文件包
    case end    //文件传输完毕
}

class BLEDataManager: NSObject {
    static let shared = BLEDataManager()
    
    ///设备会发三次C：还未开始时、文件名发送完毕时、文件传输完毕时
    var otaCType:OTACType = .start
    ///升级数据是否传输完毕，完毕则升级进入收尾。
    var dataFinished:Bool = false
    
    ///升级包拆分
    var packetArray:[Data] = []
    ///当前进度
    var packetIndex:Int = 0
    
    ///重设，将数据初始化
    func reset() {
        otaCType = .start
        packetArray = []
        packetIndex = 0
        dataFinished = false
    }
    
    ///处理升级包
    func dealWithYModem(statusData: Data, fileName:String, fileData:Data) -> Data? {
        //返回包
        var data: Data?
        let status = HexString(data: statusData)
        
        if status == OTAC {
            if otaCType == .start {
                //发送文件名的包
                data = dealWithFileNamePacket(fileName: fileName, fileLength: fileData.count)
                print("C:发送文件名包")
            } else if otaCType == .end {
                //发送结束的空包(SOH 00 FF 00~00(共128个) CRCH CRCL)
                data = dealWithEndPacket()//dealWithFileNamePacket(fileName: "", fileLength: 0)
                print("C:发送结束后的空包：\([UInt8](data!))")
            } else {
                //发送升级包，将升级包拆解放入数组中存储
                if packetArray.count == 0 {
                    packetArray = dealWithFilePacket(fileData: fileData)
                    packetIndex = 0
                }
                data = packetArray[packetIndex]
                print("C:发送首包拆分包")
            }
        } else if status == OTAACK {
            if otaCType == .start {
                //发送完文件名的包后收到ACK。
                //之后再收到设备发送的C,开启文件传输
                otaCType = .main
                print("ACK:设备收到文件名包")
            } else if otaCType == .main {
                //当收到设备的第二个C并发送完首包后再次收到ACK。
                //收到ACK后，继续发送下一包，直到最后一包发送完毕。
                packetIndex += 1
                packetArray = dealWithFilePacket(fileData: fileData)
                if packetIndex < packetArray.count {
                    data = packetArray[packetIndex]
                    //print("ACK:发送拆分包:\(packetIndex)")
                } else {
                    //升级包发送完毕，发送EOT给设备
                    data = Data([0x04])
                    otaCType = .end
                    print("ACK:拆分包发送完毕，发送第一次EOT")
                }
            } else if otaCType == .end{
                //设备再次收到EOT后回应ACK，数据传输完毕
                //后设备还会发送一次C，回应后升级结束
                if dataFinished == true {
                    //设备升级完成之后重置设备状态
                    reset()
                    print("ACK:传输完毕后设备收到空包最后回应ACK，升级流程结束")
                } else {
                    dataFinished = true
                    print("ACK:设备再次收到EOT后回应ACK，数据传输完毕")
                }
            }
        } else if status == OTANAK {
            //设备收到第一次EOT之后返回NAK
            //收到NAK之后需要重新发送EOT给设备，后设备再回应ACK
            if packetIndex > 0 {
                data = Data([0x04])
                otaCType = .end
                print("NAK:设备收到第一次EOT后回应NAK，后App重新发送EOT")
            }
        }
        
        return data
    }
    
    ///设置升级包的头包，包含文件的包名
    private func dealWithFileNamePacket(fileName: String, fileLength: Int) -> Data {
        let data = fileName.data(using: String.Encoding.utf8) ?? Data()
        let nameBytes = [UInt8](data)
        var packBytes:[UInt8] = [UInt8](Data(count: Int(PACKET_SIZE) + 5))
        
        PrepareIntialPacket(&packBytes, nameBytes, UInt32(fileLength))
        let packData = Data(packBytes)
        
        return packData
    }
    
    ///设置升级包的拆分包
    private func dealWithFilePacket(fileData:Data) -> [Data] {
        let size = Int(PACKET_1K_SIZE)
        var dataArray:[Data] = []
        var index = 0
        var i = 0
        
        while i < fileData.count  {
            var len = size
            let tempI = i
            if fileData.count - i < size {
                len = fileData.count - i
                i = fileData.count
            } else {
                i += len
            }
            index += 1
            let subData = NSData(data: fileData).subdata(with: NSRange(location: tempI, length: len))
            var subBytes = [UInt8](subData)
            let pData = Data(count: size + 5)
            var pBytes:[UInt8] = [UInt8](pData)
            
            PreparePacket(&subBytes, &pBytes, UInt8(index), UInt32(subData.count))
            
            let data = Data(pBytes)
            dataArray.append(data)
        }
        return dataArray
    }
    
    ///设置升级完成后的空包
    private func dealWithEndPacket() -> Data {
        var packBytes:[UInt8] = [UInt8](Data(count: Int(PACKET_SIZE) + 5))
        PrepareEndPacket(&packBytes)
        
        return Data(packBytes)
    }
    
    //data转为十六进制
    func HexString(data:Data) -> String {
        let bytes = [UInt8](data)
        let hexStr = bytes.hexString
        
        return hexStr
    }
    
    ///计算校验
    private func setupCheckout(data: Data) -> UInt8 {
        let bytes:[UInt8] = [UInt8](data)
        var bigByte: UInt32 = 0
        
        for index in 0..<bytes.count {
            let byte = bytes[index]
            bigByte += UInt32(byte)
        }
        
        let rByte = UInt8(bigByte & 0xFF)
        
        return rByte
    }
}

extension Array where Element == UInt8 {
    var hexString: String {
        return self.compactMap { String(format: "%02x", $0).uppercased() }
            .joined(separator: "")
    }
}
