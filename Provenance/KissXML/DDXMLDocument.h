#import <Foundation/Foundation.h>
#import "DDXMLElement.h"
#import "DDXMLNode.h"

/**
 * Welcome to KissXML.
 * 
 * The project page has documentation if you have questions.
 * https://github.com/robbiehanson/KissXML
 * 
 * If you're new to the project you may wish to read the "Getting Started" wiki.
 * https://github.com/robbiehanson/KissXML/wiki/GettingStarted
 * 
 * KissXML provides a drop-in replacement for Apple's NSXML class cluster.
 * The goal is to get the exact same behavior as the NSXML classes.
 * 
 * For API Reference, see Apple's excellent documentation,
 * either via Xcode's Mac OS X documentation, or via the web:
 * 
 * https://github.com/robbiehanson/KissXML/wiki/Reference
**/

enum {
	DDXMLDocumentXMLKind = 0,
	DDXMLDocumentXHTMLKind,
	DDXMLDocumentHTMLKind,
	DDXMLDocumentTextKind
};
typedef NSUInteger DDXMLDocumentContentKind;

@interface DDXMLDocument : DDXMLNode
{
}

- (id)initWithXMLString:(NSString *)string options:(NSUInteger)mask error:(NSError **)error;
//- (id)initWithContentsOfURL:(NSURL *)url options:(NSUInteger)mask error:(NSError **)error;
- (id)initWithData:(NSData *)data options:(NSUInteger)mask error:(NSError **)error;
//- (id)initWithRootElement:(DDXMLElement *)element;

//+ (Class)replacementClassForClass:(Class)cls;

//- (void)setCharacterEncoding:(NSString *)encoding; //primitive
//- (NSString *)characterEncoding; //primitive

//- (void)setVersion:(NSString *)version;
//- (NSString *)version;

//- (void)setStandalone:(BOOL)standalone;
//- (BOOL)isStandalone;

//- (void)setDocumentContentKind:(DDXMLDocumentContentKind)kind;
//- (DDXMLDocumentContentKind)documentContentKind;

//- (void)setMIMEType:(NSString *)MIMEType;
//- (NSString *)MIMEType;

//- (void)setDTD:(DDXMLDTD *)documentTypeDeclaration;
//- (DDXMLDTD *)DTD;

//- (void)setRootElement:(DDXMLNode *)root;
- (DDXMLElement *)rootElement;

//- (void)insertChild:(DDXMLNode *)child atIndex:(NSUInteger)index;

//- (void)insertChildren:(NSArray *)children atIndex:(NSUInteger)index;

//- (void)removeChildAtIndex:(NSUInteger)index;

//- (void)setChildren:(NSArray *)children;

//- (void)addChild:(DDXMLNode *)child;

//- (void)replaceChildAtIndex:(NSUInteger)index withNode:(DDXMLNode *)node;

- (NSData *)XMLData;
- (NSData *)XMLDataWithOptions:(NSUInteger)options;

//- (id)objectByApplyingXSLT:(NSData *)xslt arguments:(NSDictionary *)arguments error:(NSError **)error;
//- (id)objectByApplyingXSLTString:(NSString *)xslt arguments:(NSDictionary *)arguments error:(NSError **)error;
//- (id)objectByApplyingXSLTAtURL:(NSURL *)xsltURL arguments:(NSDictionary *)argument error:(NSError **)error;

//- (BOOL)validateAndReturnError:(NSError **)error;

@end
