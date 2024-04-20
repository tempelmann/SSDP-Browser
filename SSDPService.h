//
//  SSDPService.h
//  SSDP Browser
//
//  Created by Thomas Tempelmann on 20.04.24.
//  Copyright © 2024 Thomas Tempelmann. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SSDPService : NSObject

@property (readonly) NSString	* __nullable uniqueServiceName;
@property (readonly) NSString	* __nullable location;

- (instancetype) initHost:(NSString*)host response:(NSString*)response;

@end

NS_ASSUME_NONNULL_END
