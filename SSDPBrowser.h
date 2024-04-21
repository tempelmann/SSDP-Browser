//
//  SSDPBrowser.h
//  SSDP Browser
//
//  Created by Thomas Tempelmann on 21.04.24.
//  Copyright © 2024 Thomas Tempelmann. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol DiscoveryDelegate <NSObject>
	- (void) discoveryDidFindUUID:(NSString*)uuid name:(NSString*)name data:(NSDictionary*)data;
	- (void) discoveryDidFinish;
@end

@interface SSDPBrowser : NSObject
	- (void) discoverWithDelegate:(id<DiscoveryDelegate>)delegate;
	- (void) stop;
@end

NS_ASSUME_NONNULL_END
