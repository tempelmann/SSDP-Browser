//
//  SSDPService.m
//  SSDP Browser
//
//  Created by Thomas Tempelmann on 20.04.24.
//  Copyright © 2024 Thomas Tempelmann. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SSDPService.h"

@interface SSDPService()
	@property NSString	* __nullable uniqueServiceName;
	@property NSString	* __nullable location;
	@property NSString	* __nullable host;
	@property NSString	* __nullable server;
	@property NSString	* __nullable searchTarget;
	@property NSDictionary<NSString*,NSString*> *responseHeaders;
@end

@implementation SSDPService

- (instancetype) initHost:(NSString*)host response:(NSString*)response
{
	if (self = [super init]) {
		self.host = host;
		NSDictionary *headers = [self parse:response];
		self.responseHeaders = headers;
		self.location = headers[@"LOCATION"];
		self.server = headers[@"SERVER"];
		self.searchTarget = headers[@"ST"];
		self.uniqueServiceName = headers[@"USN"];
	}
	return self;
}

- (NSString*) description {
	return [NSString stringWithFormat:@"loc: %@, server: %@, st: %@, usn: %@", self.location, self.server, self.searchTarget, self.uniqueServiceName];
}

- (NSDictionary*) parse:(NSString*)response {
	NSMutableDictionary *result = NSMutableDictionary.new;
	NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"^([^\\r\\n:]+): (.*)$" options:NSRegularExpressionAnchorsMatchLines error:nil]; 
	[re enumerateMatchesInString:response options:0 range:NSMakeRange(0, response.length) usingBlock:^(NSTextCheckingResult * _Nullable match, NSMatchingFlags flags, BOOL * _Nonnull stop) {
		NSRange keyCaptureGroupIndex = [match rangeAtIndex:1];
		NSString *key = [response substringWithRange:keyCaptureGroupIndex];
		NSRange valueCaptureGroupIndex = [match rangeAtIndex:2];
		NSString *value = [response substringWithRange:valueCaptureGroupIndex];
		result[key.uppercaseString] = value;
	}];
	return result;
}

@end
