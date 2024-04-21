//
//  Document.m
//  SSDP Browser
//
//  Created by Thomas Tempelmann on 27.02.24.
//

#import "SSDPDocument.h"
#import "TreeNode.h"

#if 1
	#import "SSDPBrowser.h"
#else
	#import "SSDP_Browser-Swift.h"
#endif

@interface SSDPDocument () <DiscoveryDelegate, NSWindowDelegate, NSSearchFieldDelegate>
	@property (weak) IBOutlet NSProgressIndicator *searchSpinner;
	@property (weak) IBOutlet NSOutlineView *outlineView;
	@property (strong) IBOutlet NSTreeController *treeController;
	@property (weak) IBOutlet NSSearchField *searchField;

	@property (nonatomic) TreeNode *model;	// this is what the NSOutlineView will show via the treeController
	@property SSDPBrowser *browser;
	@property BOOL isSearching;
	@property NSDictionary *filterMatchAttributes;
@end

@implementation SSDPDocument

- (instancetype)init {
    self = [super init];
    if (self) {
		self.model = TreeNode.new;
		self.browser = SSDPBrowser.new;
		self.filterMatchAttributes = @{
			NSForegroundColorAttributeName:[NSColor colorNamed:@"match fg color"],	// from assets
			NSBackgroundColorAttributeName:[NSColor colorNamed:@"match bg color"]
		};
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
	[self.outlineView setSortDescriptors:@[
		[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES],
		[NSSortDescriptor sortDescriptorWithKey:@"value" ascending:YES]
	]];
}

#define NSJSONWritingWithoutEscapingSlashes 8 // API_AVAILABLE(macos(10.15), ios(13.0), watchos(6.0), tvos(13.0)) = (1UL << 3),

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError {
/* TODO: TreeNodes need to support serialization
	return [NSJSONSerialization dataWithJSONObject:self.model.children options:NSJSONWritingPrettyPrinted|NSJSONWritingWithoutEscapingSlashes error:outError];
*/	return nil;
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError {
/* TODO: TreeNodes need to support serialization
	[self clearFilter];
	self.model.children = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:outError];
	return YES;
*/	return NO;
}

#pragma mark - SSDP discovery handling

- (IBAction)startDiscovery:(id)sender {
	self.isSearching = YES;
	self.searchSpinner.hidden = NO;
	[self.searchSpinner startAnimation:self];
	[self.browser discoverWithDelegate:self];
}

- (TreeNode*) makeTreeNodeFrom:(NSObject*)value withName:(NSString*)name {
	TreeNode *result = TreeNode.new;
	result.name = name;
	if ([value isKindOfClass:NSDictionary.class]) {
		NSMutableArray *children = NSMutableArray.array;
		[(NSDictionary*)value enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSObject *obj, BOOL *stop) {
			[children addObject:[self makeTreeNodeFrom:obj withName:key]];
		}];
		[result setChildren:children];
	} else {
		assert ([value isKindOfClass:NSString.class]);
		result.value = (NSString*)value;
	}
	return result;
}

- (TreeNode* _Nullable) findTreeNodeIn:(TreeNode* _Nonnull)parent match:(BOOL(^)(TreeNode* _Nonnull child))match {
	for (TreeNode *child in parent.children) {
		if (match(child)) {
			return child;
		}
	}
	return nil;
}

- (void)discoveryDidFindUUID:(NSString * _Nonnull)uuid name:(NSString * _Nonnull)name data:(NSDictionary * _Nonnull)data
{
	// 	NSLog(@"add %@", uuid);

	if (data.count == 1 && data[@"root"] != nil) {	// replace the top "root" element with its single child element
		data = data[@"root"];
	}
	
	// Create the new node
	TreeNode *newNode = [self makeTreeNodeFrom:data withName:name];
	newNode.value = uuid;
	
	TreeNode *root = self.model;
	TreeNode *parent = root;	// the default parent is the root node

	// If we have multiple entries with the same name (but different uuid), we collect them all as children under a new intermediate node
	TreeNode *match = [self findTreeNodeIn:root match:^BOOL(TreeNode * _Nonnull child) { return [child.name isEqualToString:newNode.name]; }];
	if (match) {
		BOOL isInsertedNode = match.value.length == 0;	// the added parent node gets no value
		if (isInsertedNode) {
			// The intermediate node becomes the new destination where the new node gets added
			parent = match;
		} else {
			// We had only a single item with this name, now we have two -> merge them under a new intermediate node that we insert at the root
			TreeNode *newParent = TreeNode.new;
			newParent.name = match.name;
			NSMutableArray *children = parent.children.mutableCopy;
			[children removeObject:match];
			[children addObject:newParent];
			parent.children = children;
			newParent.children = @[match];
			parent = newParent;
		}
	}

	// Avoid duplicating entries with the same name and uuid
	match = [self findTreeNodeIn:parent match:^BOOL(TreeNode * _Nonnull child) {
		return [child.name isEqualToString:newNode.name] && [child.value isEqualToString:newNode.value];
	}];
	NSMutableArray *newChildren = parent.children.mutableCopy;
	if (match) {
		[newChildren removeObject:match];
	}
	[newChildren addObject:newNode];
	parent.children = newChildren;	// The assignment triggers a reload in the OutlineView via its NSTreeController
}

- (void)discoveryDidFinish { 
	self.isSearching = NO;
	[self.searchSpinner stopAnimation:self];
	self.searchSpinner.hidden = YES;
}

#pragma mark - results filtering

- (NSString*) currentFilter {
	return self.searchField.stringValue;
}

- (void) clearFilter {
	self.searchField.stringValue = @"";
}

- (IBAction)filterUpdate:(id)sender {
	NSString *filter = self.currentFilter;
	if (filter.length == 0) {
		self.model.predicate = nil;
	} else {
		self.model.predicate = [NSPredicate predicateWithBlock:^BOOL(TreeNode *node, NSDictionary<NSString *,id> *bindings) {
			if ([node.name localizedCaseInsensitiveContainsString:filter]) return YES;
			if ([node.value localizedCaseInsensitiveContainsString:filter]) return YES;
			return NO;
		}];
		// Let's open all remaining nodes so that the matched items are all visible
		[self.outlineView expandItem:nil expandChildren:YES];
	}
}

- (id) highlightedObjectValue:(HighlightingTextFieldCell*)cell node:(TreeNode*)node {
	// We want to replace the string with an attributed string if there's a search filter set
	NSString *value;
	if (cell.tag == 0) {
		value = node.name;
	} else {
		value = node.value;
	}
	NSString *filter = self.currentFilter;
	if (value == nil || filter.length == 0) {
		return value;
	}
	
	// Now replace the plain string with one that highlights the search string
	NSAssert([value isKindOfClass:NSString.class], @"value must be string");
	NSInteger findPos = 0;
	NSMutableAttributedString *attributedString = nil;
	while (1) {
		NSRange findRange = { findPos, value.length - findPos };
		NSRange range = [value rangeOfString:filter options:NSCaseInsensitiveSearch range:findRange locale:NSLocale.currentLocale];
		if (range.location == NSNotFound) {
			break;
		}
		findPos = range.location + range.length;
		if (attributedString == nil) {
			attributedString = [[NSMutableAttributedString alloc] initWithString:value];
		}
		NSDictionary *attributes = self.filterMatchAttributes;
		[attributedString setAttributes:attributes range:range];
	}
	if (attributedString) {
		value = (NSString*)attributedString;
	}

	return value;
}

@end
