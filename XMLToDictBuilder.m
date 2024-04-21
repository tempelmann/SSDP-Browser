//
//  XMLToDictBuilder.m
//  SSDP Browser
//
//  Created by Thomas Tempelmann on 21.04.24.
//  Copyright © 2024 Thomas Tempelmann. All rights reserved.
//

#import "XMLToDictBuilder.h"

@interface XMLToDictBuilder() <NSXMLParserDelegate>
	@property NSXMLParser *parser;
	@property NSMutableDictionary *dict;
	@property NSMutableDictionary *currentNode;
	@property NSMutableArray<NSMutableDictionary*> *nodeStack;
	@property NSMutableString *collectedText;
@end

@implementation XMLToDictBuilder

- (NSDictionary*)parseData:(NSData*)data {
	self.parser = [NSXMLParser.alloc initWithData:data];
	self.parser.delegate = self;
	[self.parser parse];
	return self.dict;
}

-(void)parserDidStartDocument:(NSXMLParser *)parser {
	self.dict = NSMutableDictionary.new;
	self.nodeStack = NSMutableArray.new;
	self.currentNode = self.dict;
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict {   
	self.collectedText = NSMutableString.new;
	NSMutableDictionary *newNode = NSMutableDictionary.new;
	self.currentNode[elementName] = newNode;
	[self.nodeStack addObject:self.currentNode];
	self.currentNode = newNode;
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
	BOOL isEmptyNode = self.currentNode.count == 0;
	self.currentNode = self.nodeStack.lastObject;
	[self.nodeStack removeLastObject];
	if (isEmptyNode && self.collectedText.length > 0) {
		self.currentNode[elementName] = self.collectedText;
	}
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
	[self.collectedText appendString:[string stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]];
}

@end
