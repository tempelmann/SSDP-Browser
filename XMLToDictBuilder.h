//
//  XMLToDictBuilder.h
//  SSDP Browser
//
//  Created by Thomas Tempelmann on 21.04.24.
//  Copyright © 2024 Thomas Tempelmann. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface XMLToDictBuilder : NSObject

- (NSDictionary*)parseData:(NSData*)data;

@end

NS_ASSUME_NONNULL_END
