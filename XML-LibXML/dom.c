#include <libxml/tree.h>
#include <libxml/encoding.h>
#include <libxml/xmlmemory.h>
#include <libxml/parser.h>
#include <libxml/xmlIO.h>
#include <libxml/xpath.h>
#include <libxml/xpathInternals.h>

xmlDocPtr
domCreateDocument( xmlChar *version, xmlChar *enc ){
  xmlDocPtr doc = 0;
  doc = xmlNewDoc( version );  
  doc->charset  = XML_CHAR_ENCODING_UTF8;
  doc->encoding = xmlStrdup(enc);
  return doc;
}

/* void */
/* domFreeDocument( xmlDocPtr d ) { */
/*   xmldomFreeDOM( d ) ; */
/* } */

xmlNodePtr
domCreateTextNode( xmlDocPtr self,xmlChar *content ){
  /* we must convert the content */
  if ( self != 0 && content != 0 ) {
    xmlBufferPtr in, out;
    
    in = xmlBufferCreate();
    out =xmlBufferCreate();
    
    xmlBufferCat( in, content );
    xmlCharEncInFunc( xmlGetCharEncodingHandler( xmlParseCharEncoding(self->doc->encoding) ), out, in);

    return xmlNewDocText( self->doc,out->content );  
  }
  return 0;
}

xmlNodePtr
domCreateElement( xmlDocPtr self, xmlChar *strNodeName ) {
  xmlNodePtr elem = xmlNewNode( 0,strNodeName );
  elem->next = 0;
  elem->prev = 0;
  elem->children = 0 ;
  elem->last = 0;
  elem->doc = self;
  return elem;
}

xmlNodePtr
domCreateComment( xmlDocPtr self , xmlChar * strNodeContent ){
  xmlNodePtr elem = 0;

  if ( ( self != 0 ) && ( strNodeContent != 0 ) ) {
    xmlBufferPtr in, out;
    
    in = xmlBufferCreate();
    out =xmlBufferCreate();
    
    xmlBufferCat( in,  strNodeContent );
    xmlCharEncInFunc( xmlGetCharEncodingHandler( xmlParseCharEncoding(self->doc->encoding) ), out, in);

    elem = xmlNewComment( out->content );
    elem->next = 0;
    elem->prev = 0;
    elem->children = 0 ;
    elem->last = 0;
    elem->doc = self->doc;   
  }

  return elem;
}

xmlNodePtr
domCreateCDATASection( xmlDocPtr self , xmlChar * strNodeContent ){
  xmlNodePtr elem = 0;

  if ( ( self != 0 ) && ( strNodeContent != 0 ) ) {
    xmlBufferPtr in, out;
    
    in = xmlBufferCreate();
    out =xmlBufferCreate();
    
    xmlBufferCat( in,  strNodeContent );
    xmlCharEncInFunc( xmlGetCharEncodingHandler( xmlParseCharEncoding(self->doc->encoding) ), out, in);

    elem = xmlNewCDataBlock( self,  out->content, xmlStrlen(out->content) );
    elem->next = 0;
    elem->prev = 0;
    elem->children = 0 ;
    elem->last = 0;
    elem->doc = self->doc;   
  }

  return elem;
}


xmlNodePtr
domUnbindNode( xmlNodePtr );

xmlNodePtr
domAppendChild( xmlNodePtr self,
		xmlNodePtr newChild ){
  /* unbind the new node if nessecary ...  */
  if ( newChild == 0 ){
    return 0;
  }
  if ( self == 0 ) {
    return newChild;
  }

  newChild= domUnbindNode( newChild );
  /* fix the document if they are from different documents 
   * actually this has to be done for ALL nodes in the subtree... 
   **/
  if ( self->doc != newChild->doc ) {
    newChild->doc = self->doc;
  }
  
  if ( self->children != 0 ) {
    if ( newChild->type   == XML_TEXT_NODE && 
	 self->last->type == XML_TEXT_NODE ) {
      int len = xmlStrlen(newChild->content);
      xmlNodeAddContentLen(self->last, newChild->content, len);
      xmlFreeNode( newChild );
      return self->last;
    }
    else {
      self->last->next = newChild;
      newChild->prev = self->last;
      self->last = newChild;
      newChild->parent= self;
    }
  }
  else {
    self->children = newChild;
    self->last     = newChild;
    newChild->parent= self;
  }
  return newChild;
}

xmlNodePtr
domRemoveNode( xmlNodePtr self, xmlNodePtr old ) {
  if ( (self != 0)  && (old!=0) && (self == old->parent ) ) {
    domUnbindNode( old );
  }
  return old ;
}

xmlNodePtr
domUnbindNode( xmlNodePtr self ) {
  if ( (self != 0) && (self->parent != 0) ) { 
    if ( self->next != 0 )
      self->next->prev = self->prev;
    if ( self->prev != 0 )
      self->prev->next = self->next;
    if ( self == self->parent->last ) 
      self->parent->last = self->prev;
    if ( self == self->parent->children ) 
      self->parent->children = self->next;
    
    self->parent = 0;
    self->next   = 0;
    self->prev   = 0;
  }

  return self;
}

xmlNodePtr
domReplaceChild( xmlNodePtr self, xmlNodePtr new, xmlNodePtr old ) {
  if ( new == 0 ) {
    return old;
  }
  if ( self== 0 ){
    return 0;
  }
  if ( old == 0 ) {
    domAppendChild( self, new );
    return old;
  }
  if ( old->parent != self ) {
    /* should not do this!!! */
    return new;
  }
  new = domUnbindNode( new ) ;
  new->parent = self;
  
  /* this piece is quite important */
  if ( new->doc != self->doc ) {
    new->doc = self->doc;
  }

  if ( old->next != 0 ) 
    old->next->prev = new;
  if ( old->prev != 0 ) 
    old->prev->next = new;
  
  new->next = old->next;
  new->prev = old->prev;
  
  if ( old == self->children )
    self->children = new;
  if ( old == self->last )
    self->last = new;
  
  old->parent = 0;
  old->next   = 0;
  old->prev   = 0;
 
  return old;
}

xmlNodePtr 
domDocumentElement( xmlDocPtr doc ) {
  xmlNodePtr cld=0;
  if ( doc != 0 && doc->doc != 0 && doc->doc->children != 0 ) {
    cld= doc->doc->children;
    while ( cld != 0 && cld->type != XML_ELEMENT_NODE ) 
      cld= cld->next;
  
  }
  return cld;
}

/**
 * setDocumentElement:
 * @doc: the document
 * @newRoot: the new rootnode
 *
 * a document can have only ONE root node, so this function searches
 * the first element and relaces this element with newRoot.
 * 
 * Returns the old root node.
 **/
xmlNodePtr
domSetDocumentElement( xmlDocPtr doc, xmlNodePtr newRoot ) { 
  return domReplaceChild( (xmlNodePtr)doc->doc, 
			  newRoot, 
			  domDocumentElement( doc )) ;
}

/** 
 * domSetAttribute:
 * @self: the node
 * @name: name of the attribute
 * @content: the value of the attribute
 * 
 * A node may have several attributes. This function wraps the
 * original xmlSetProp function from libxml2. The function assumes the
 * string has the same encoding as the document. The content passed to
 * the node will be encoded to UTF-8, so the data is in the correct
 * format.
 *
 * Returns the newly created attribute node
 **/
xmlAttrPtr
domSetAttribute( xmlNodePtr self, xmlChar *name,  xmlChar *content ) {
  if ( self!= 0 &&  name!= 0 && content != 0 ) {
    xmlBufferPtr in, out;
    xmlDocPtr doc = self->doc;
    xmlAttrPtr rv = 0;
    in = xmlBufferCreate();
    out =xmlBufferCreate();

    xmlBufferCat( in, content );
    if ( doc != 0 ) {
      xmlCharEncInFunc(xmlGetCharEncodingHandler( xmlParseCharEncoding(doc->encoding) ) ,
		       out, in ) ;
      rv = xmlSetProp( self, name, out->content );
    }
    else {
      rv = xmlSetProp( self, name, content );
    }

    return rv;    
  }
  return 0;
}

xmlChar*
domGetAttribute( xmlNodePtr self, xmlChar* name ) {
  return xmlGetProp( self, name );
}

xmlNodePtr
domCloneNode( xmlNodePtr self, int deep ) {
  return xmlCopyNode( self, deep );
}

int
domHasChildNodes( xmlNodePtr self ) {
  return self!=0 && self->children!=0 ? 1: 0;
}

const xmlChar*
domNodeName( xmlNodePtr n ) {
  if ( n == 0 ) 
    return 0;
  return (const xmlChar*) n->name;
}

const xmlChar*
domNodeValue( xmlNodePtr n ) {
  if ( n == 0 ) 
    return 0;
  return (const xmlChar* ) n->content ;
}

void
domSetNodeValue( xmlNodePtr n , xmlChar* val ){
  if ( n == 0 ) 
    return;
  if( n->content != 0 ) {
    xmlFree( n->content );
  }
  n->content = xmlStrdup( val );
}

xmlNodePtr
domParentNode( xmlNodePtr n ) {
  return n!=0 ?n->parent:0;
}

void
domSetParentNode( xmlNodePtr self, xmlNodePtr p ) {
  if( self != 0 ){
    if( self->parent != p ){
      domUnbindNode( self );
      self->parent = p;
      if( p->doc != self->doc ) {
	self->doc = p->doc;
      }
    }
  }
}

xmlNodePtr
domNextSibling( xmlNodePtr n ){
  return n == 0 ? 0 : n->next;
}

xmlNodePtr 
domPreviousSibling( xmlNodePtr n ) {
  return n==0?0:n->prev;
}

xmlNodePtr 
domFirstChild( xmlNodePtr n ) {
  return n==0 ? 0 : n->children;
}

xmlNodePtr 
domLastChild( xmlNodePtr n ) {
  return n==0 ? 0:n->last;
}

xmlDocPtr
domOwnerDocument( xmlNodePtr n ) {
  /* this is actually a little mode complicated ... */
  return n==0?0:n->doc;
}

void
domRemoveAttribute( xmlNodePtr n , xmlChar* name ) {
  xmlAttrPtr attr;
  if ( n== 0) 
    return;
  attr = n->properties;
  while ( (attr) && (xmlStrcmp(attr->name, name ) != 0 ) ) {
    attr = attr->next;
  }
  xmlRemoveProp( attr );
}

xmlNodeSetPtr
domGetElementsByTagName( xmlNodePtr n, xmlChar* name ){
  xmlNodeSetPtr rv = 0;
  xmlNodePtr cld = 0;

  if ( n != 0 && name != 0 ) {
    cld = n->children;
    while ( cld ) {
      if ( xmlStrcmp( name, cld->name ) == 0 ){
	if ( rv == 0 ) {
	  rv = xmlXPathNodeSetCreate( cld ) ;
	}
	else {
	  xmlXPathNodeSetAdd( rv, cld );
	}
      }
      cld = cld->next;
    }
  }
  
  return rv;
}

/* ****************************************************** *
 * nodelist functions
 **/

/* new */
xmlNodeSetPtr
domCreateNodeList( void ) {
  return xmlXPathNodeSetCreate( 0 );
}

/* destroy */
void
domFreeNodeList( xmlNodeSetPtr nl ) {
  if ( nl != 0 ) {
    xmlXPathFreeNodeSet( nl );
  }
}

/* add */ 
void
domAddNodeToNodeList( xmlNodeSetPtr list, xmlNodePtr node ){
  if( list != 0 && node != 0 ) 
    xmlXPathNodeSetAdd( list, node );
}

/* drop ?? */
void 
domRemoveNodeFromNodeList( xmlNodeSetPtr list, xmlNodePtr node ) {
  if ( list != 0 && node != 0 )
    xmlXPathNodeSetDel( list, node );
}

/* length is allways important :) */
int 
domNodeListLength( xmlNodeSetPtr nl ) {
  return nl!= 0? nl->nodeNr : 0;
}

/* access the items */
xmlNodePtr 
domNodeListItem( xmlNodeSetPtr nl, int pos ){
  if ( nl != 0 && pos >= 0 && pos < nl->nodeNr ) {
    return nl->nodeTab[pos];
  }
  return 0;
}
