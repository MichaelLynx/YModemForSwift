# YModemForSwift
 swift版YModem蓝牙文件传输协议



## 中文

简介：

工作需要使用YModem协议传输数据，但是网上没找到swift版的，只好自己写一个。

使用方式：

使用的时候需要将`BLEDataManager`、`YModem.c`、`YModem.h`三个文件拉入工程，并对`YModem.h`设置桥接。



## English

Description：

Need to use YModem to transfer data by bluetooth but I couldn't find an aticle of swift version about it. So I made one.

Usage:

You need to drag the following three files to your project: `BLEDataManager`、`YModem.c`、`YModem.h` and make a bridging file for `YModem.h` when you want to use it.