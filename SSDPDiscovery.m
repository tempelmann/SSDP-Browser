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
	@property NSError *lastError;
	@property BOOL stopped;
	- (BOOL) isDiscovering;
@end

@implementation SSDPDiscovery

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data
                                             fromAddress:(NSData *)address
                                       withFilterContext:(nullable id)filterContext
{
	NSString *host = [GCDAsyncUdpSocket hostFromAddress:address];
	NSString *msg = [NSString.alloc initWithData:data encoding:NSUTF8StringEncoding];
	if (msg.length > 0) {
		SSDPService *service = [SSDPService.alloc initHost:host response:msg];
		[self.delegate ssdpDiscovery:self didDiscoverService:service];
	}
}

-(void)udpSocket:(GCDAsyncUdpSocket *)sock didNotSendDataWithTag:(long)tag dueToError:(NSError *)error {
	NSLog(@"%s %@", __func__, error);
}

- (void)udpSocketDidClose:(GCDAsyncUdpSocket *)sock withError:(NSError  * _Nullable)error
{
	[self.sockets removeObject:sock];
	if (error) {
		if (error.code == 65) {
			// no need to report "not reachable"
		} else {
			NSLog(@"Socket error: %@", error);
			self.lastError = error;
		}
	}
	[self checkFinish];
}

- (void) checkFinish {
	if (!self.isDiscovering) {
		if (self.lastError && [self.delegate respondsToSelector:@selector(ssdpDiscovery:didFinishWithError:)]) {
			[self.delegate ssdpDiscovery:self didFinishWithError:self.lastError];
		} else if ([self.delegate respondsToSelector:@selector(ssdpDiscoveryDidFinish:)]) {
			[self.delegate ssdpDiscoveryDidFinish:self];
		}
		self.delegate = nil;
	}
}

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

- (void) discoverServiceForDuration:(NSTimeInterval)duration searchTarget:(NSString*)searchTarget port:(SInt32)port onInterfaces:(NSArray<NSString*>*)onInterfaces
{
	id tmpDelegate = self.delegate;
	self.delegate = nil;
	[self forceStop];
	self.lastError = nil;
	self.stopped = NO;
	self.delegate = tmpDelegate;
	
	if ([self.delegate respondsToSelector:@selector(ssdpDiscoveryDidStart:)]) {
		[self.delegate ssdpDiscoveryDidStart:self];
	}

	dispatch_queue_t queue = dispatch_get_main_queue();

	for (__strong NSString *interface in onInterfaces) {
		if (interface.length == 0) {
			interface = nil;
		}
		// Determine the multicast address based on the interface's address type (ipv4 vs ipv6)
		BOOL useIP4;
		NSString *multicastAddr;
		NSData *interface4 = nil;
		NSData *interface6 = nil;
		[GCDAsyncUdpSocket convertInterfaceDescription:interface port:port intoAddress4:&interface4 address6:&interface6];
		if (interface4) {
			multicastAddr = @"239.255.255.250";
			useIP4 = YES;
		} else if (interface6) {
			multicastAddr = @"ff02::c";	// use "ff02::c" for "link-local" or "ff05::c" for "site-local"
			useIP4 = NO;
		} else {
			continue;
		}
		// Set up the UDP socket
		NSError *error = nil;
		GCDAsyncUdpSocket *socket = [GCDAsyncUdpSocket.alloc initWithDelegate:self delegateQueue:queue];
		socket.userTag = interface;
		@try {
			[socket enableReusePort:YES error:&error];
			if (error) {
				[NSException raise:SSDPDiscoveryException format:@"enableReusePort failed; %@", error];
			}
			[socket setIPv4Enabled:useIP4];
			[socket setIPv6Enabled:!useIP4];
			NSString *interfaceForBind = [interface componentsSeparatedByString:@"%"].lastObject;
			if (interfaceForBind.length == 0) {
				interfaceForBind = nil;
			}
			[socket bindToPort:0 interface:interfaceForBind error:&error];
			if (error) {
				[NSException raise:SSDPDiscoveryException format:@"bindToPort failed; %@", error];
			}
			[socket beginReceiving:&error];
			if (error) {
				[NSException raise:SSDPDiscoveryException format:@"bindToPort failed; %@", error];
			}
			NSString *message = @"M-SEARCH * HTTP/1.1\r\nMAN: \"ssdp:discover\"\r\nHOST: %@:%d\r\nST: %@\r\nMX: %d\r\n\r\n";
			message = [NSString stringWithFormat:message, multicastAddr, (int)port, searchTarget, (int)duration];
			[socket sendData:[message dataUsingEncoding:NSUTF8StringEncoding] toHost:multicastAddr port:port withTimeout:-1 tag:0];
			[self.sockets addObject:socket];

		} @catch (NSException *exception) {
			[socket close];
			NSLog (@"Socket error: %@ on interface %@", error, interface.length > 0 ? interface : @"localhost");
			self.lastError = error;
		}

	}

	if (self.isDiscovering) {    // Might we run into a race condition here?
		dispatch_after (dispatch_time(DISPATCH_TIME_NOW, (int64_t)(duration * NSEC_PER_SEC)), queue, ^{
			[self stop];
		});
	} else {
		if ([self.delegate respondsToSelector:@selector(ssdpDiscoveryDidFinish:)]) {
			[self.delegate ssdpDiscoveryDidFinish:self];
		}
	}
}

- (void) forceStop {
	self.stopped = YES;
	while (self.isDiscovering) {
		GCDAsyncUdpSocket *socket = self.sockets.lastObject;
		[self.sockets removeLastObject];
		[socket close];
	}
}

- (void) stop {
	if (self.isDiscovering) {
		[self forceStop];
	}
}

@end
