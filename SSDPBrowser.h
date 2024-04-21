//
//  SSDPBrowser.h
//  SSDP Browser
//
//  Created by Thomas Tempelmann on 21.04.24.
//  Copyright © 2024 Thomas Tempelmann. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class SSDPBrowser;

@protocol SSDPBrowserDelegate <NSObject>
	- (void) browser:(SSDPBrowser*)browser didFindUUID:(NSString*)uuid name:(NSString*)name data:(NSDictionary*)data;
	- (void) browserDidFinish:(SSDPBrowser*)browser;
@end

@interface SSDPBrowser : NSObject
	- (void) discoverEverythingOnAllInterfacesWithDelegate:(id<SSDPBrowserDelegate>)delegate;
	- (void) discoverRootdevicesOnAllInterfacesWithDelegate:(id<SSDPBrowserDelegate>)delegate;
	- (void) discover:(NSString*)target onAllInterfacesWithDelegate:(id<SSDPBrowserDelegate>)delegate;
	- (void) discover:(NSString*)target onInterfaces:(NSArray<NSString*>*)interfaces delegate:(id<SSDPBrowserDelegate>)delegate;
	- (void) stop;
	- (NSArray<NSString*>*) allInterfacesIncludeIPv6:(BOOL)includeIPv6;
@end

NS_ASSUME_NONNULL_END
