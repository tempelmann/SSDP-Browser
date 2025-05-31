//
//  AppDelegate.h
//  SSDP Browser
//
//  Created by Thomas Tempelmann on 27.02.24.
//

#import <Cocoa/Cocoa.h>
#import "TreeNode.h"

@interface AppDelegate : NSObject <NSApplicationDelegate>
	@property NSClickGestureRecognizer *gesture;
	@property TreeNode *node;
@end
