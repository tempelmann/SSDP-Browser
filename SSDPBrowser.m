//
//  SSDPBrowser.m
//  SSDP Browser
//
//  Created by Thomas Tempelmann on 21.04.24.
//  Copyright © 2024 Thomas Tempelmann. All rights reserved.
//

#import "SSDPBrowser.h"
#import "SSDPDiscovery.h"
#import "XMLToDictBuilder.h"

#include <sys/types.h>
#include <sys/socket.h>
#include <ifaddrs.h>
#include <net/if.h>
#include <netdb.h>


@interface SSDPBrowser() <SSDPDiscoveryDelegate>
	@property id<SSDPBrowserDelegate> delegate;
	@property SSDPDiscovery *client;
	@property NSMutableDictionary *titleByUUID;
	@property BOOL stopped;
@end

@implementation SSDPBrowser

- (void) discoverEverythingOnAllInterfacesWithDelegate:(id<SSDPBrowserDelegate>)delegate {
	[self discover:@"ssdp:all" onAllInterfacesWithDelegate:delegate];
}

- (void) discoverRootdevicesOnAllInterfacesWithDelegate:(id<SSDPBrowserDelegate>)delegate {
	[self discover:@"upnp:rootdevice" onAllInterfacesWithDelegate:delegate];
}

- (void) discover:(NSString*)target onAllInterfacesWithDelegate:(id<SSDPBrowserDelegate>)delegate {
	[self discover:target onInterfaces:[self allInterfacesIncludeIPv6:YES] delegate:delegate];
}

- (void) discover:(NSString*)target onInterfaces:(NSArray<NSString*>*)interfaces delegate:(id<SSDPBrowserDelegate>)delegate {
	const int duration = 5;
	self.delegate = delegate;
	self.titleByUUID = NSMutableDictionary.new;
	self.client = SSDPDiscovery.new;
	self.client.delegate = self;
	[self.client discoverServiceForDuration:duration searchTarget:target port:1900 onInterfaces:interfaces specificAddress:nil];
}

- (void) query:(NSString*)target address:(NSString*)address delegate:(id<SSDPBrowserDelegate>)delegate {
	const int duration = 5;
	self.delegate = delegate;
	self.client = SSDPDiscovery.new;
	self.client.delegate = self;
	[self.client discoverServiceForDuration:duration searchTarget:target port:1900 onInterfaces:@[] specificAddress:address];
}

- (void) stop {
	[self.client stop];
}

- (void) ssdpDiscovery:(SSDPDiscovery *)discovery didDiscoverService:(SSDPService *)service { 
	NSString *uuid = service.uniqueServiceName;
	if (uuid) {
		if (self.titleByUUID[uuid] == nil) {
			// Download the XML description in order to determine the service's name
			NSString *location = service.location;
			NSURL *url = [NSURL URLWithString:location];
			NSURLSessionTask *task = [NSURLSession.sharedSession dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
				if (self.titleByUUID[uuid] == nil && data.length > 0) {
					XMLToDictBuilder *xmlToDict = XMLToDictBuilder.new;
					NSMutableDictionary *dict = [[xmlToDict parseData:data] mutableCopy];
					NSString *friendlyName = dict[@"root"][@"device"][@"friendlyName"];
					if (dict[@"root"][@"URLBase"] == nil) {
						NSRange range = [service.location rangeOfString:@"\\b/\\b" options:NSRegularExpressionSearch];
						if (range.location != NSNotFound) {
							dict[@"root"][@"URLBase (inferred)"] = [service.location substringToIndex:range.location];
						} else {
							dict[@"root"][@"URLBase (inferred)"] = service.location;
						}
					}
					self.titleByUUID[uuid] = friendlyName;
					dispatch_async(dispatch_get_main_queue(), ^{
						[self.delegate browser:self didFindUUID:uuid name:friendlyName data:dict];
					});
				}
			}];
			[task resume];
		}
	}
}

- (void) ssdpDiscoveryDidFinish:(SSDPDiscovery*)discovery {
	self.stopped = true;
	dispatch_async(dispatch_get_main_queue(), ^{
		[self.delegate browserDidFinish:self];
	});
}

- (void) ssdpDiscovery:(SSDPDiscovery*)discovery didFinishWithError:(NSError*)error {
	self.stopped = true;
	dispatch_async(dispatch_get_main_queue(), ^{
		[self.delegate browserDidFinish:self];
	});
}

- (NSArray<NSString*>*) allInterfacesIncludeIPv6:(BOOL)includeIPv6 {	// https://stackoverflow.com/a/25627545/43615
	NSMutableArray *addresses = NSMutableArray.new;

	// Get list of all interfaces on the local machine:
	struct ifaddrs *ifaddr;
	getifaddrs(&ifaddr);
	
	// For each interface ...
	struct ifaddrs *ptr = ifaddr;
	do {
		uint32_t flags = ptr->ifa_flags;
		struct sockaddr* addr = ptr->ifa_addr;

		// Check for running IPv4, IPv6 interfaces. Skip the loopback interface.
		if ((flags & (IFF_UP|IFF_RUNNING|IFF_LOOPBACK)) == (IFF_UP|IFF_RUNNING)) {
			if (addr->sa_family == AF_INET || (includeIPv6 && addr->sa_family == AF_INET6)) {
				// Convert interface address to a human readable string:
				char hostname[NI_MAXHOST];
				if (getnameinfo(ptr->ifa_addr, addr->sa_len, (char*)&hostname, sizeof(hostname), nil, 0, NI_NUMERICHOST) == 0) {
					NSString *address = [NSString stringWithUTF8String:hostname];
					[addresses addObject:address];
				}
			}
		}
	} while ((ptr = ptr->ifa_next) != nil);
	
	freeifaddrs(ifaddr);
	
	return addresses;
}

@end
