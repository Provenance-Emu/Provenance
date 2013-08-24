#import "DDXML.h"


// We can't rely solely on NSAssert, because many developers disable them for release builds.
// Our API contract requires us to keep these assertions intact.
#define DDXMLAssert(condition, desc, ...)                                                                 \
  do{                                                                                                     \
    if(!(condition)) {                                                                                    \
      [[NSAssertionHandler currentHandler] handleFailureInMethod:_cmd                                     \
                                                          object:self                                     \
                                                            file:[NSString stringWithUTF8String:__FILE__] \
                                                      lineNumber:__LINE__                                 \
                                                     description:(desc), ##__VA_ARGS__];                  \
    }                                                                                                     \
  }while(NO)


// Create assertion to ensure xml node is not a zombie.
#if DDXML_DEBUG_MEMORY_ISSUES
#define DDXMLNotZombieAssert()                                                                            \
  do{                                                                                                     \
    if(DDXMLIsZombie(genericPtr, self)) {                                                                      \
      NSString *desc = @"XML node is a zombie - It's parent structure has been freed!";                   \
      [[NSAssertionHandler currentHandler] handleFailureInMethod:_cmd                                     \
                                                          object:self                                     \
                                                            file:[NSString stringWithUTF8String:__FILE__] \
                                                      lineNumber:__LINE__                                 \
                                                     description:desc];                                   \
    }                                                                                                     \
  }while(NO)
#endif

#define DDLastErrorKey @"DDXML:LastError"



/**
 * DDXMLNode can represent several underlying types, such as xmlNodePtr, xmlDocPtr, xmlAttrPtr, xmlNsPtr, etc.
 * All of these are pointers to structures, and all of those structures start with a pointer, and a type.
 * The xmlKind struct is used as a generic structure, and a stepping stone.
 * We use it to check the type of a structure, and then perform the appropriate cast.
 * 
 * For example:
 * if(genericPtr->type == XML_ATTRIBUTE_NODE)
 * {
 *     xmlAttrPtr attr = (xmlAttrPtr)genericPtr;
 *     // Do something with attr
 * }
**/
struct _xmlKind {
	void * ignore;
	xmlElementType type;
};
typedef struct _xmlKind *xmlKindPtr;

/**
 * Most xml types all start with this standard structure. In fact, all do except the xmlNsPtr.
 * We will occasionally take advantage of this to simplify code when the code wouldn't vary from type to type.
 * Obviously, you cannnot cast a xmlNsPtr to a xmlStdPtr.
**/
struct _xmlStd {
	void * _private;
	xmlElementType type;
	const xmlChar *name;
	struct _xmlNode *children;
	struct _xmlNode *last;
	struct _xmlNode *parent;
	struct _xmlStd *next;
	struct _xmlStd *prev;
	struct _xmlDoc *doc;
};
typedef struct _xmlStd *xmlStdPtr;


NS_INLINE BOOL IsXmlAttrPtr(void *kindPtr)
{
	return ((xmlKindPtr)kindPtr)->type == XML_ATTRIBUTE_NODE;
}

NS_INLINE BOOL IsXmlNodePtr(void *kindPtr)
{
	switch (((xmlKindPtr)kindPtr)->type)
	{
		case XML_ELEMENT_NODE       :
		case XML_PI_NODE            : 
		case XML_COMMENT_NODE       : 
		case XML_TEXT_NODE          : 
		case XML_CDATA_SECTION_NODE : return YES;
		default                     : return NO;
	}
}

NS_INLINE BOOL IsXmlDocPtr(void *kindPtr)
{
	return ((xmlKindPtr)kindPtr)->type == XML_DOCUMENT_NODE;
}

NS_INLINE BOOL IsXmlDtdPtr(void *kindPtr)
{
	return ((xmlKindPtr)kindPtr)->type == XML_DTD_NODE;
}

NS_INLINE BOOL IsXmlNsPtr(void *kindPtr)
{
	return ((xmlKindPtr)kindPtr)->type == XML_NAMESPACE_DECL;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface DDXMLNamespaceNode : DDXMLNode
{
	// The xmlNsPtr type doesn't store a reference to it's parent.
	// This is here to fix the problem, and make this class more compatible with the NSXML classes.
	xmlNodePtr nsParentPtr;
}

+ (id)nodeWithNsPrimitive:(xmlNsPtr)ns nsParent:(xmlNodePtr)parent owner:(DDXMLNode *)owner;
- (id)initWithNsPrimitive:(xmlNsPtr)ns nsParent:(xmlNodePtr)parent owner:(DDXMLNode *)owner;

- (xmlNodePtr)_nsParentPtr;
- (void)_setNsParentPtr:(xmlNodePtr)parentPtr;

// Overrides several methods in DDXMLNode

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface DDXMLAttributeNode : DDXMLNode
{
	// The xmlAttrPtr type doesn't allow for ownership of a namespace.
	// 
	// In other types, such as xmlNodePtr:
	// - nsDef stores namespaces that are owned by the node (have been alloced by the node).
	// - ns is simply a pointer to the default namespace of the node, which may or may not reside in its own nsDef list.
	// 
	// The xmlAttrPtr only has a ns, it doesn't have a nsDef list.
	// Which completely makes sense really, since namespaces have to be defined elsewhere.
	// 
	// This is here to maintain compatibility with the NSXML classes,
	// where one can assign a namespace to an attribute independently.
	xmlNsPtr attrNsPtr;
}

+ (id)nodeWithAttrPrimitive:(xmlAttrPtr)attr owner:(DDXMLNode *)owner;
- (id)initWithAttrPrimitive:(xmlAttrPtr)attr owner:(DDXMLNode *)owner;

// Overrides several methods in DDXMLNode

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface DDXMLInvalidNode : DDXMLNode
{
}

// Overrides several methods in DDXMLNode

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface DDXMLNode (PrivateAPI)

+ (id)nodeWithUnknownPrimitive:(xmlKindPtr)kindPtr owner:(DDXMLNode *)owner;

+ (id)nodeWithPrimitive:(xmlKindPtr)kindPtr owner:(DDXMLNode *)owner;
- (id)initWithPrimitive:(xmlKindPtr)kindPtr owner:(DDXMLNode *)owner;

- (BOOL)_hasParent;

+ (void)getHasPrefix:(BOOL *)hasPrefixPtr localName:(NSString **)localNamePtr forName:(NSString *)name;
+ (void)getPrefix:(NSString **)prefixPtr localName:(NSString **)localNamePtr forName:(NSString *)name;

+ (void)recursiveStripDocPointersFromNode:(xmlNodePtr)node;

+ (void)detachNamespace:(xmlNsPtr)ns fromNode:(xmlNodePtr)node;
+ (void)removeNamespace:(xmlNsPtr)ns fromNode:(xmlNodePtr)node;
+ (void)removeAllNamespacesFromNode:(xmlNodePtr)node;

+ (void)detachAttribute:(xmlAttrPtr)attr andClean:(BOOL)clean;
+ (void)detachAttribute:(xmlAttrPtr)attr;
+ (void)removeAttribute:(xmlAttrPtr)attr;
+ (void)removeAllAttributesFromNode:(xmlNodePtr)node;

+ (void)detachChild:(xmlNodePtr)child andClean:(BOOL)clean andFixNamespaces:(BOOL)fixNamespaces;
+ (void)detachChild:(xmlNodePtr)child;
+ (void)removeChild:(xmlNodePtr)child;
+ (void)removeAllChildrenFromNode:(xmlNodePtr)node;

BOOL DDXMLIsZombie(void *xmlPtr, DDXMLNode *wrapper);

+ (NSError *)lastError;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface DDXMLElement (PrivateAPI)

+ (id)nodeWithElementPrimitive:(xmlNodePtr)node owner:(DDXMLNode *)owner;
- (id)initWithElementPrimitive:(xmlNodePtr)node owner:(DDXMLNode *)owner;

- (DDXMLNode *)_recursiveResolveNamespaceForPrefix:(NSString *)prefix atNode:(xmlNodePtr)nodePtr;
- (NSString *)_recursiveResolvePrefixForURI:(NSString *)uri atNode:(xmlNodePtr)nodePtr;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface DDXMLDocument (PrivateAPI)

+ (id)nodeWithDocPrimitive:(xmlDocPtr)doc owner:(DDXMLNode *)owner;
- (id)initWithDocPrimitive:(xmlDocPtr)doc owner:(DDXMLNode *)owner;

@end
