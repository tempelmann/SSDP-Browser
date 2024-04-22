//
//  TreeNode.m
//  SSDP Browser
//
//  Created by Thomas Tempelmann on 27.02.24.
//  Copyright © 2024 Thomas Tempelmann. All rights reserved.
//

#import "TreeNode.h"

@interface TreeNode()
@end

@implementation TreeNode

- (NSString *) description {
	return [NSString stringWithFormat:@"%@ (%ld)", self.name, self.count];
}

- (id) objectRef {	// we can bind this to the NSCells in the outline view, and then use an NSCell subclass to examine this object
	return self;
}

- (TreeNode*) childByName:(NSString*)name {
	for (TreeNode *child in self.children) {
		if ([child.name isEqualToString:name]) {
			return child;
		}
	}
	return nil;
}

@end
