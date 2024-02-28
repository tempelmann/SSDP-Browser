//
//  Document.h
//  SSDP Browser
//
//  Created by Thomas Tempelmann on 27.02.24.
//

#import <Cocoa/Cocoa.h>
#import "TreeNode.h"
#import "HighlightingTextFieldCell.h"

@interface SSDPDocument : NSDocument
- (id) highlightedObjectValue:(HighlightingTextFieldCell*)cell node:(TreeNode*)node;
@end
