#ifndef __LIBXML_DOM_H__
#define __LIBXML_DOM_H__

#include <libxml/tree.h>
#include <libxml/xpath.h>

xmlDocPtr
domCreateDocument( xmlChar* version, 
		   xmlChar *encoding );
void
domFreeDocument( xmlDocPtr document); 


/**
 * part A:
 *
 * class Node
 **/

/* A.1 specified section */
int 
domHasChildNodes( xmlNodePtr self );

xmlNodePtr
domAppendChild( xmlNodePtr self,
		xmlNodePtr newChild );
xmlNodePtr
domReplaceChild( xmlNodePtr self,
		 xmlNodePtr oldChlid,
		 xmlNodePtr newChild );
/* xmlNodePtr */
/* domInsertBefore( xmlNodePtr self,  */
/* 		 xmlNodePtr newChild, */
/* 		 xmlNodePtr refChild ); */
xmlNodePtr
domCloneNode( xmlNodePtr self, int deep );
xmlNodePtr
domRemoveNode(  xmlNodePtr self,
		xmlNodePtr Child );

/* A.2 data access functions */
const xmlChar* 
domNodeName( xmlNodePtr self );
const xmlChar*
domNodeValue( xmlNodePtr self );
xmlNodePtr 
domParentNode( xmlNodePtr self );

xmlNodePtr 
domNextSibling( xmlNodePtr self );
xmlNodePtr
domPreviousSibling( xmlNodePtr self );
xmlNodePtr 
domFirstChild( xmlNodePtr self );
xmlNodePtr
domLastChild( xmlNodePtr self );
xmlDocPtr 
domOwnerDocument( xmlNodePtr self );

/* A.3 extra functionality not specified in DOM L1/2*/
void
domSetNodeValue( xmlNodePtr self, xmlChar* value );
void
domSetParentNode( xmlNodePtr self, 
		  xmlNodePtr newParent );

xmlNodePtr
domUnbindNode(  xmlNodePtr self );

/** 
 * part B:
 *
 * class Document
 **/

xmlNodePtr
domCreateTextNode( xmlDocPtr self, xmlChar *content );
xmlNodePtr
domCreateElement(  xmlDocPtr self, xmlChar *name );
xmlNodePtr
domCreateComment( xmlDocPtr self, xmlChar *content );
xmlNodePtr
domCreateCDATASection( xmlDocPtr self, xmlChar *content );
/* extra document functions */ 
xmlNodePtr
domDocumentElement( xmlDocPtr document );
xmlNodePtr
domSetDocumentElement( xmlDocPtr document, 
		       xmlNodePtr newRoot);

/**
 * part C:
 *
 * class Element
 **/

xmlAttrPtr
domSetAttribute( xmlNodePtr self,
	      xmlChar *name, 
	      xmlChar *content );
xmlChar*
domGetAttribute( xmlNodePtr self,
	      xmlChar *name ); 
void
domRemoveAttribute( xmlNodePtr self,
		 xmlChar* name );

xmlNodeSetPtr
domGetElementsByTagName( xmlNodePtr self, xmlChar* name );

/**
 * part D
 *
 * class Nodelist  
 **/

/* this is a simple wrapper function */
xmlNodeSetPtr
domCreateNodeList( void );

void
domAddNodeToNodeList( xmlNodeSetPtr list, xmlNodePtr node );
void 
domRemoveNodeFromNodeList( xmlNodeSetPtr list, xmlNodePtr node );

int 
domNodeListLength( xmlNodeSetPtr nl );
xmlNodePtr 
domNodeListItem( xmlNodeSetPtr nl, int pos );
void
domFreeNodeList( xmlNodeSetPtr nodelist );

#endif
