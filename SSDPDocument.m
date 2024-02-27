//
//  Document.m
//  SSDP Browser
//
//  Created by Thomas Tempelmann on 27.02.24.
//

#import "SSDPDocument.h"
#import "SSDP_Browser-Swift.h"

@interface SSDPDocument () <DiscoveryDelegate, NSWindowDelegate>
	@property (weak) IBOutlet NSProgressIndicator *searchSpinner;
	@property (weak) IBOutlet NSOutlineView *tableView;
	@property (strong) IBOutlet NSTreeController *treeController;

	@property (nonatomic) NSMutableArray *model;	// this is what the NSOutlineView will show via the treeController
	@property SSDPBrowser *browser;
	@property BOOL isSearching;
@end

@implementation SSDPDocument

- (instancetype)init {
    self = [super init];
    if (self) {
		self.model = NSMutableArray.array;
		self.browser = SSDPBrowser.new;
    }
    return self;
}

+ (BOOL)autosavesInPlace {
	return YES;
}

- (NSString *)windowNibName {
	return @"SSDPDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *)windowController {
	[self startDiscovery:self];
	[self.tableView setSortDescriptors:@[
		[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES],
		[NSSortDescriptor sortDescriptorWithKey:@"value" ascending:YES]
	]];
}

#define NSJSONWritingWithoutEscapingSlashes 8 // API_AVAILABLE(macos(10.15), ios(13.0), watchos(6.0), tvos(13.0)) = (1UL << 3),

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError {
	return [NSJSONSerialization dataWithJSONObject:self.model options:NSJSONWritingPrettyPrinted|NSJSONWritingWithoutEscapingSlashes error:outError];
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError {
	[self willChangeValueForKey:@"model"];
	self.model = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:outError];
	[self didChangeValueForKey:@"model"];
	return YES;
}

#pragma mark - SSDP discovery handling

- (IBAction)startDiscovery:(id)sender {
	self.isSearching = YES;
	self.searchSpinner.hidden = NO;
	[self.searchSpinner startAnimation:self];
	[self.browser discoverWithDelegate:self];
}

- (NSMutableDictionary*) makeNodeFrom:(NSObject*)value withName:(NSString*)name {
	NSMutableDictionary *result = NSMutableDictionary.dictionary;	// has keys: name, value, children, isLeaf, count
	result[@"name"] = name;
	if ([value isKindOfClass:NSDictionary.class]) {
		NSMutableArray *children = NSMutableArray.array;
		[(NSDictionary*)value enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSObject *obj, BOOL *stop) {
			[children addObject:[self makeNodeFrom:obj withName:key]];
		}];
		result[@"children"] = children;
		result[@"count"] = @(children.count);
	} else {
		result[@"isLeaf"] = @YES;
		result[@"value"] = value;
	}
	return result;
}

- (void)discoveryDidFindWithUuid:(NSString * _Nonnull)uuid name:(NSString * _Nonnull)name data:(NSDictionary * _Nonnull)data {
	// 	NSLog(@"add %@", uuid);
	if (data.count == 1 && data[@"root"] != nil) {
		data = data[@"root"];
	}
	NSMutableDictionary *value = [self makeNodeFrom:data withName:name];
	value[@"value"] = uuid;
	[self willChangeValueForKey:@"model"];
	[self.model addObject:value];
	[self didChangeValueForKey:@"model"];
}

- (void)discoveryDidFinish { 
	self.isSearching = NO;
	[self.searchSpinner stopAnimation:self];
	self.searchSpinner.hidden = YES;
}

@end
