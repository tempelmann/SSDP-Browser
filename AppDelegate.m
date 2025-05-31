//
//  AppDelegate.m
//  SSDP Browser
//
//  Created by Thomas Tempelmann on 27.02.24.
//

#import "AppDelegate.h"
#import "HighlightingTextFieldCell.h"

@interface AppDelegate ()
@end

@implementation AppDelegate

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
	return YES;
}

- (void)applicationDidFinishLaunching:(NSNotification *) notification {
	self.gesture = NSClickGestureRecognizer.new;
	self.gesture.buttonMask = 0x1;
	self.gesture.numberOfClicksRequired = 2;
	self.gesture.target = self;
	self.gesture.action = @selector(onClick:);
	self.node = nil;
}

- (void)onClick:(NSGestureRecognizer *) sender {
	if (self.node != nil && self.node.value != nil) {
		NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
		[pasteboard clearContents];
		[pasteboard setString:self.node.value forType:NSPasteboardTypeString];
	}
}

@end
