//
//  HighlightingTextFieldCell.m
//  SSDP Browser
//
//  Created by Thomas Tempelmann on 28.02.24.
//  Copyright © 2024 Thomas Tempelmann. All rights reserved.
//

#import "HighlightingTextFieldCell.h"
#import "SSDPDocument.h"
#import "AppDelegate.h"
#import "TreeNode.h"

@implementation HighlightingTextFieldCell

//
// This is a bit of a trick: The Cells in the NSOutlineView bind to the "objectRef" property of TreeNode,
// and their NSTextFieldCell instances have different `tag` values set (first col is 0, the other is 1).
// This function below gets called when the NSCell is set up, and it gets the bound value passed here,
// i.e. the value from TreeNode.objectRef, which is the TreeNode itself. We then pass it to our
// SSDPDocument class which can decide which string to assign to this NSCell's objectValue.
//
- (void)setObjectValue:(id)objectValue {
	if ([objectValue isKindOfClass:TreeNode.class]) {
		//NSLog(@"%p", objectValue);
		[self setEnabled:true];
		[(NSTextField*)self.controlView setEnabled:true];
		[(NSTextField*)self.controlView addGestureRecognizer:((AppDelegate*)[NSApplication sharedApplication].delegate).gesture];
		// we want to replace the string with an attributed string if there's a search filter set
		id docHandler = self.controlView.window.delegate;	// we blindly assume this is of the SSDPDocument type
		objectValue = [(SSDPDocument*)docHandler highlightedObjectValue:self node:objectValue];
	}
	super.objectValue = objectValue;
}

@end
