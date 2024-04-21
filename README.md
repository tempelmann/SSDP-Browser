# SSDP Browser (macOS)

This is a macOS program for finding UPnP devices that are announced on the local network via SSDP.

It looks on *all* interfaces, not just only on the default interface. Which means that it will find devices that are on a secondary subnet, for instance.

It uses Cocoa Binding excessively and is quite compact. It also uses a smart method for identifying the nodes for dynamic update of the displayed names depending on the search term, despite using an `NSTreeController`.

The ObjC source code, which is free of any Swift code since v1.0.3, includes the following 3rd party sources:

- [GCDAsyncUdpSocket](https://github.com/robbiehanson/CocoaAsyncSocket) (Public Domain), slightly modified.

It was tested on macOS 10.13, built with Xcode 10.1

![Main Window with Search exampled](Docs/MainWindow.png)
