//
//  PredicateOutlineNode.h
//  SSDP Browser
//
//  Created by Thomas Tempelmann on 27.02.24.
//  Copyright © 2024 Thomas Tempelmann. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PredicateOutlineNode : NSObject

	@property NSArray *children;
	@property NSArray *filteredChildren;
	@property (readonly) NSInteger count;
	@property (readonly) BOOL isLeaf;
	@property NSPredicate * __nullable predicate;

@end

NS_ASSUME_NONNULL_END
