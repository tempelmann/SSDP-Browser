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


@interface Discovery: NSObject <SSDPDiscoveryDelegate>
	@property (weak) id<DiscoveryDelegate> delegate;
	- (instancetype) initForDuration:(NSTimeInterval)duration delegate:(id<DiscoveryDelegate>)delegate onInterfaces:(NSArray<NSString*>*)onInterfaces;
	- (void) stop;
@end


@interface SSDPBrowser()
	@property Discovery *disc;
@end

@implementation SSDPBrowser

- (void) discoverWithDelegate:(id<DiscoveryDelegate>)delegate {
	#if true
		NSArray *addrs = [self getIFAddressesIncludeIPv6:true];
	#else
		NSArray *addrs = @[""];
	#endif
	self.disc = [Discovery.alloc initForDuration:5 delegate:delegate onInterfaces:addrs];
}

- (void) stop {
	[self.disc stop];
}

- (void) discoveryDidFindUUID:(NSString*)uuid name:(NSString*)name data:(NSDictionary*)data {
	NSLog (@"Found %@", name);
}

- (void) discoveryDidFinish {
	NSLog (@"Finished.");
}

- (NSArray*) getIFAddressesIncludeIPv6:(BOOL)includeIPv6 {	// https://stackoverflow.com/a/25627545/43615
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


#pragma mark -


@interface Discovery()
	@property SSDPDiscovery *client;
	@property NSMutableDictionary *titleByUUID;
	@property BOOL stopped;
@end

@implementation Discovery

- (instancetype) initForDuration:(NSTimeInterval)duration delegate:(id<DiscoveryDelegate>)delegate onInterfaces:(NSArray<NSString*>*)onInterfaces {
	if (self = [super init]) {
		self.delegate = delegate;
		self.titleByUUID = NSMutableDictionary.new;
		self.client = SSDPDiscovery.new;
		self.client.delegate = self;
		[self.client discoverServiceForDuration:duration searchTarget:@"ssdp:all" port:1900 onInterfaces:onInterfaces];
	}
	return self;
}

- (void) stop {
	[self.client stop];
}

- (void) ssdpDiscovery:(SSDPDiscovery *)discovery didDiscoverService:(SSDPService *)service { 
	NSString *uuid = service.uniqueServiceName;
	if (uuid) {
		if (self.titleByUUID[uuid] == nil) {
			// Download the XML description in order to determine the service's name
			NSURL *url = [NSURL URLWithString:service.location];
			NSURLSessionTask *task = [NSURLSession.sharedSession dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
				if (self.titleByUUID[uuid] == nil && data.length > 0) {
					XMLToDictBuilder *xmlToDict = XMLToDictBuilder.new;
					NSDictionary *dict = [xmlToDict parseData:data];
					NSString *friendlyName = dict[@"root"][@"device"][@"friendlyName"];
					self.titleByUUID[uuid] = friendlyName;
					dispatch_async(dispatch_get_main_queue(), ^{
						[self.delegate discoveryDidFindUUID:uuid name:friendlyName data:dict];
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
		[self.delegate discoveryDidFinish];
	});
}

- (void) ssdpDiscovery:(SSDPDiscovery*)discovery didFinishWithError:(NSError*)error {
	self.stopped = true;
	dispatch_async(dispatch_get_main_queue(), ^{
		[self.delegate discoveryDidFinish];
	});
}

@end
