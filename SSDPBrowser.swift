//
//  SSDPBrowser.swift
//  SSDP Browser
//
//  Created by Thomas Tempelmann on 14.02.24.
//

import Cocoa

typealias SSDPDiscoveryDelegate = SSDPDiscoverySwiftDelegate
typealias SSDPDiscovery = SSDPDiscoverySwift
typealias SSDPService = SSDPServiceSwift

public class SSDPBrowser: NSObject, DiscoveryDelegate
{
	var disc: Discovery? = nil
	
	@objc public func discover(delegate: DiscoveryDelegate) {
		#if false
		let addrs = self.getIFAddresses (includeIPv6: true)
		#else
		let addrs = [""]
		#endif
		self.disc = Discovery (delegate: delegate, onInterfaces:addrs)
	}

	@objc public func stop() {
		self.disc?.stop();
	}

	public func discoveryDidFind(uuid: String, name: String, data: NSDictionary) {
		print ("Found \(name)")
		//if name.localizedCaseInsensitiveContains("Fritz") { return }
		//self.textView.string.append("Found \(name)\n")
		//self.textView.string.append("Found \(name): \(data)\n\n")
	}
	
	public func discoveryDidFinish() {
		print ("Finished.")
	}
	
	func getIFAddresses(includeIPv6: Bool = true) -> [String] {	// https://stackoverflow.com/a/25627545/43615
		var addresses = [String]()

		// Get list of all interfaces on the local machine:
		var ifaddr : UnsafeMutablePointer<ifaddrs>?
		guard getifaddrs(&ifaddr) == 0 else { return [] }
		guard let firstAddr = ifaddr else { return [] }

		// For each interface ...
		for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
			let flags = Int32(ptr.pointee.ifa_flags)
			let addr = ptr.pointee.ifa_addr.pointee

			// Check for running IPv4, IPv6 interfaces. Skip the loopback interface.
			if (flags & (IFF_UP|IFF_RUNNING|IFF_LOOPBACK)) == (IFF_UP|IFF_RUNNING) {
				if addr.sa_family == UInt8(AF_INET) || includeIPv6 && addr.sa_family == UInt8(AF_INET6) {
					// Convert interface address to a human readable string:
					var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
					if (getnameinfo(ptr.pointee.ifa_addr, socklen_t(addr.sa_len), &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST) == 0) {
						let address = String(cString: hostname)
						// removing the %… suffix from IPv6 doesn't seem to make a difference:
						//	address = String(address.split(separator: "%", maxSplits: 1, omittingEmptySubsequences: true).first ?? "")
						addresses.append(address)
					}
				}
			}
		}

		freeifaddrs(ifaddr)
		return addresses
	}

}

private extension NSMutableDictionary {	// https://talk.objc.io/episodes/S01E31-mutating-untyped-dictionaries
	subscript(node key: Key) -> XMLToDictBuilder.node? {
		get { return self[key] as? XMLToDictBuilder.node }
		set { self[key] = newValue }
	}
	subscript(string key: Key) -> String? {
		get { return self[key] as? String }
		set { self[key] = newValue }
	}
}

private class XMLToDictBuilder: NSObject, XMLParserDelegate {
	typealias node = NSMutableDictionary // [String: Any]
	var dict = node()
	var collectedText: String? = nil
	var currentNode: node?
	var nodeStack = [node]()
	func parserDidStartDocument(_ parser: XMLParser) {
		dict = [:]
		currentNode = dict
	}
	func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
		collectedText = nil
		let newNode = node()
		currentNode![elementName] = newNode
		nodeStack.append(currentNode!)
		currentNode = newNode
	}
	func parser(_ parser: XMLParser, foundCharacters string: String) {
		collectedText = collectedText ?? "" + string
	}
	func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
		let isEmptyNode = currentNode!.count == 0
		currentNode = nodeStack.popLast()!
		if isEmptyNode && collectedText != nil {
			currentNode![elementName] = collectedText
		}
	}
}

@objc public protocol DiscoveryDelegate {
	func discoveryDidFind (uuid: String, name: String, data: NSDictionary)
	func discoveryDidFinish ()
}

@objc class Discovery: NSObject, SSDPDiscoveryDelegate
{
	public var delegate: DiscoveryDelegate?

	private let client = SSDPDiscovery()
	private var titleByUUID = [String: String]()
	private var stopped = false

	init(forDuration: TimeInterval = 5, delegate: DiscoveryDelegate? = nil, onInterfaces:[String] = [""]) {
		super.init()
		self.delegate = delegate
		self.client.delegate = self
		self.client.discoverService (forDuration:forDuration, searchTarget:"ssdp:all", port:1900, onInterfaces:onInterfaces)
	}
	
	func stop() {
		self.client.stop();
	}

	func ssdpDiscovery(_: SSDPDiscovery, didDiscoverService service: SSDPService) {
		let uuid = service.uniqueServiceName // The "UUID" we need is the entire urn
		if let uuid = uuid {
			if titleByUUID[uuid] == nil {
				// download the XML description in order to determine the TV's name
				let url = URL(string: service.location!)!
				let task = URLSession.shared.dataTask(with: url) {(data, response, error) in
					if self.titleByUUID[uuid] == nil {
						if let data = data {
							let parser = XMLParser(data: data)
							let result = XMLToDictBuilder()
							parser.delegate = result
							parser.parse()
							let friendlyName = result.dict[node:"root"]?[node:"device"]?[string:"friendlyName"] ?? "?"
							self.titleByUUID[uuid] = friendlyName
							DispatchQueue.main.async { [weak self] in
								self?.delegate?.discoveryDidFind(uuid: uuid, name: friendlyName, data: result.dict)
							}
						}
					}
				}
				task.resume()
			}
		}
	}
	
	func ssdpDiscoveryDidFinish(_ discovery: SSDPDiscovery) {
		self.stopped = true
		DispatchQueue.main.async { [weak self] in
			self?.delegate?.discoveryDidFinish()
		}
	}

	func ssdpDiscovery(_ discovery: SSDPDiscovery, didFinishWithError error: NSErrorPointer) {
		self.stopped = true
		DispatchQueue.main.async { [weak self] in
			self?.delegate?.discoveryDidFinish()
		}
	}
}
