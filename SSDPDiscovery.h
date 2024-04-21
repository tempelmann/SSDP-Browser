//
//  SSDPDiscovery.h
//  SSDP Browser
//
//  Created by Thomas Tempelmann on 20.04.24.
//  Copyright © 2024 Thomas Tempelmann. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SSDPService.h"

NS_ASSUME_NONNULL_BEGIN

@class SSDPDiscovery;

@protocol SSDPDiscoveryDelegate <NSObject>

	- (void) ssdpDiscovery:(SSDPDiscovery*)discovery didDiscoverService:(SSDPService*)service;

	@optional
	- (void) ssdpDiscoveryDidStart:(SSDPDiscovery*)discovery;
	- (void) ssdpDiscovery:(SSDPDiscovery*)discovery didFinishWithError:(NSError*)error;
	- (void) ssdpDiscoveryDidFinish:(SSDPDiscovery*)discovery;	// without error

@end

@interface SSDPDiscovery : NSObject

	@property (nonatomic, weak) id<SSDPDiscoveryDelegate> delegate;

	- (void) discoverServiceForDuration:(NSTimeInterval)duration /*10*/ searchTarget:(NSString*)searchTarget /*"ssdp:all"*/ port:(UInt16)port /*1900*/ onInterfaces:(NSArray<NSString*>*)onInterfaces;
	- (void) stop;

@end

NS_ASSUME_NONNULL_END
