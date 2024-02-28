//
//  TreeNode.h
//  SSDP Browser
//
//  Created by Thomas Tempelmann on 27.02.24.
//  Copyright © 2024 Thomas Tempelmann. All rights reserved.
//

#import "PredicateOutlineNode.h"

NS_ASSUME_NONNULL_BEGIN

@interface TreeNode : PredicateOutlineNode

	@property NSString * __nonnull  name;
	@property NSString * __nullable value;

	- (id) objectRef;

@end

NS_ASSUME_NONNULL_END
