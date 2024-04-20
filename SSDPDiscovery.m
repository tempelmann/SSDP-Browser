//
//  SSDPDiscovery.m
//  SSDP Browser
//
//  Created by Thomas Tempelmann on 20.04.24.
//  Copyright © 2024 Thomas Tempelmann. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SSDPDiscovery.h"
#import "GCDAsyncUdpSocket.h"


static NSExceptionName SSDPDiscoveryException = @"SSDPDiscoveryException";	// used only here, not thrown to callers


@interface SSDPDiscovery() <GCDAsyncUdpSocketDelegate>
	@property NSMutableArray<GCDAsyncUdpSocket*> *sockets;

	- (BOOL) isDiscovering;
@end

@implementation SSDPDiscovery

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data
                                             fromAddress:(NSData *)address
                                       withFilterContext:(nullable id)filterContext
{
	NSLog(@"Received: %@", [GCDAsyncUdpSocket hostFromAddress:address]);
}

- (void)udpSocketDidClose:(GCDAsyncUdpSocket *)sock withError:(NSError  * _Nullable)error
{
	[self.sockets removeObject:sock];
	NSLog(@"Error: %@", error);
}


/*
- (void) readResponses
{
	for (GCDAsyncUdpSocket *socket in self.sockets) {
		NSMutableData *data = NSMutableData.new;
		//	let (bytesRead, address) = try socket.readDatagram(into: &data)
		if (bytesRead > 0) {
			let response = String(data: data, encoding: .utf8);
			let (remoteHost, _) = Socket.hostnameAndPort(from: address!);
			self.delegate?.ssdpDiscovery(self, didDiscoverService: SSDPService(host: remoteHost, response: response!));
		}
		if (error) {
			self.forceStop();
			self.delegate?.ssdpDiscovery(self, didFinishWithError: error);
		}
	}
}
- (void) readResponsesForDuration:(NSTimeInterval)duration {
	dispatch_queue_t queue = dispatch_get_global_queue (QOS_CLASS_USER_INITIATED, 0);
	dispatch_async(queue, ^{
		while (self.isDiscovering) {
			[self readResponses];
		}
	});
	dispatch_after (dispatch_time(DISPATCH_TIME_NOW, (int64_t)(duration * NSEC_PER_SEC)), queue, ^{
		[self stop];
	});
}
*/

- (instancetype) init {
	if (self = [super init]) {
		self.sockets = NSMutableArray.new;
	}
	return self;
}

- (void) dealloc {
	[self stop];
}

- (BOOL) isDiscovering {
	return self.sockets.count > 0;
}

- (void) forceStop{
	while (self.isDiscovering) {
		GCDAsyncUdpSocket *socket = self.sockets.lastObject;
		[self.sockets removeLastObject];
		[socket close];
	}
}


- (void) discoverServiceForDuration:(NSTimeInterval)duration searchTarget:(NSString*)searchTarget port:(SInt32)port onInterfaces:(NSArray<NSString*>*)onInterfaces
{
	if ([self.delegate respondsToSelector:@selector(ssdpDiscoveryDidStart:)]) {
		[self.delegate ssdpDiscoveryDidStart:self];
	}
    
	for (__strong NSString *interface in onInterfaces) {
		if (interface.length == 0) {
			interface = nil;
		}
		NSError *error = nil;
		GCDAsyncUdpSocket *socket = [GCDAsyncUdpSocket.alloc initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
		@try {
			[socket enableReusePort:YES error:&error];
			if (error) {
				[NSException raise:SSDPDiscoveryException format:@"enableReusePort failed; %@", error];
			}
			NSString *interfaceForBind = [interface componentsSeparatedByString:@"%"].lastObject;
			if (interfaceForBind.length == 0) {
				interfaceForBind = nil;
			}
			[socket bindToPort:port interface:interfaceForBind error:&error];
			if (error) {
				[NSException raise:SSDPDiscoveryException format:@"bindToPort failed; %@", error];
			}
			// Determine the multicast address based on the interface's address type (ipv4 vs ipv6)
			NSString *multicastAddr;
	//				case ipv6:
	//					multicastAddr = @"ff02::c";	// use "ff02::c" for "link-local" or "ff05::c" for "site-local"
			multicastAddr = @"239.255.255.250";
			[socket enableBroadcast:YES error:&error];
			if (error) {
				[NSException raise:SSDPDiscoveryException format:@"enableBroadcast %@ failed; %@", interfaceForBind, error];
			}
			[socket sendIPv4MulticastOnInterface:interfaceForBind error:&error];
			if (error) {
				[NSException raise:SSDPDiscoveryException format:@"sendIPv4MulticastOnInterface %@ failed; %@", interfaceForBind, error];
			}
			NSString *message = @"M-SEARCH * HTTP/1.1\r\nMAN: \"ssdp:discover\"\r\nHOST: %@:%d\r\nST: %@\r\nMX: %d\r\n\r\n";
			message = [NSString stringWithFormat:message, multicastAddr, (int)port, searchTarget, (int)duration];
			[socket sendData:[message dataUsingEncoding:NSASCIIStringEncoding] toHost:multicastAddr port:port withTimeout:duration tag:0];
			[self.sockets addObject:socket];

		} @catch (NSException *exception) {
			// We ignore errors here because we get "-9980(0x-26FC), No route to host" if we're not allowed to multicast, and that's difficult to foresee.
			// Also, with multiple interfaces, some may fail, and we need to ignore that, too, or it gets too difficult to handle for the caller
			// to sort out which work and which don't.
			[socket close];
			
			if (false) { //if let error: Socket.Error = error as? Socket.Error, error.errorCode == Socket.SOCKET_ERR_WRITE_FAILED {
				// no need to report "not reachable"
			} else {
				NSLog (@"Socket error: %@ on interface %@", error, interface.length > 0 ? interface : @"localhost");
			}
		} @finally {
			
		}

	}

	if (!self.isDiscovering) {    // Might we run into a race condition here?
		if ([self.delegate respondsToSelector:@selector(ssdpDiscoveryDidFinish:)]) {
			[self.delegate ssdpDiscoveryDidFinish:self];
		}
	}
}

- (void) stop {
	if (self.isDiscovering) {
		[self forceStop];
		if ([self.delegate respondsToSelector:@selector(ssdpDiscoveryDidFinish:)]) {
			[self.delegate ssdpDiscoveryDidFinish:self];
		}
	}
}

@end
