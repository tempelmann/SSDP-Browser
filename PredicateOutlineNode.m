//
//  PredicateOutlineNode.m
//  SSDP Browser
//
//  Created by Thomas Tempelmann on 27.02.24.
//
//  Based on: https://stackoverflow.com/a/66324031/43615
//

#import "PredicateOutlineNode.h"

@interface PredicateOutlineNode()
	@property NSArray *_children;
	@property NSArray *_filteredChildren;
	@property NSPredicate *_predicate;
	@property NSInteger count;
@end

@implementation PredicateOutlineNode

- (instancetype)init {
	self = [super init];
	self._children = NSMutableArray.new;
	self._filteredChildren = self._children;
	return self;
}

- (BOOL) isLeaf {
	return self.count == 0;
}

- (NSArray*) children {
	return self._children;
}

- (void) setChildren:(NSArray*)children {
	self._children = children;
	[self propagatePredicatesAndRefilterChildren];
}

- (NSArray*) filteredChildren {
	return self._filteredChildren;
}

- (void) setFilteredChildren:(NSArray*)children {
	assert(self._filteredChildren.count != children.count);
	[self willChangeValueForKey:@"filteredChildren"];
	self._filteredChildren = children;
	self.count = children.count;
	[self didChangeValueForKey:@"filteredChildren"];
}

- (NSPredicate*) predicate {
	return self._predicate;
}

- (void) setPredicate:(NSPredicate*)predicate {
	if (self._predicate != predicate) {
		self._predicate = predicate;
		if (self._children.count > 0) {
			[self propagatePredicatesAndRefilterChildren];
		}
	}
}

- (void) propagatePredicatesAndRefilterChildren {
	// Propagate the predicate down the child nodes in case either
	// the predicate or the children array changed.
	for (PredicateOutlineNode *child in self.children) {
		child.predicate = self.predicate;
	}

	// Determine the matching leaf nodes.
	NSArray *newChildren;
	if (self.predicate != nil) {
		newChildren = NSMutableArray.array;
		for (PredicateOutlineNode *child in self._children) {
			if (child.count > 0 || [self.predicate evaluateWithObject:child]) {
				[(NSMutableArray*)newChildren addObject:child];
			}
		}
	} else {
		newChildren = self.children;
	}

	// Only actually update the children if the count varies.
	if (newChildren.count != self.filteredChildren.count) {
		self.filteredChildren = newChildren;
	}
}

@end
