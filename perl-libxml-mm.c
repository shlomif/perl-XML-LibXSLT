/**
 * perl-libxml-mm.c
 * $Id$
 *
 * Basic concept:
 * perl varies in the implementation of UTF8 handling. this header (together
 * with the c source) implements a few functions, that can be used from within
 * the core module inorder to avoid cascades of c pragmas
 */

#ifdef __cplusplus
extern "C" {
#endif

#include <stdarg.h>
#include <stdlib.h>

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <libxml/parser.h>
#include <libxml/tree.h>

#ifdef __cplusplus
}
#endif

#ifdef XS_WARNINGS
#define xs_warn(string) warn(string) 
#else
#define xs_warn(string)
#endif

/**
 * this is a wrapper function that does the type evaluation for the 
 * node. this makes the code a little more readable in the .XS
 * 
 * the code is not really portable, but i think we'll avoid some 
 * memory leak problems that way.
 **/
const char*
x_PmmNodeTypeName( xmlNodePtr elem ){
    const char *name = "XML::LibXML::Node";

    if ( elem != NULL ) {
        char * ptrHlp;
        switch ( elem->type ) {
        case XML_ELEMENT_NODE:
            name = "XML::LibXML::Element";   
            break;
        case XML_TEXT_NODE:
            name = "XML::LibXML::Text";
            break;
        case XML_COMMENT_NODE:
            name = "XML::LibXML::Comment";
            break;
        case XML_CDATA_SECTION_NODE:
            name = "XML::LibXML::CDATASection";
            break;
        case XML_ATTRIBUTE_NODE:
            name = "XML::LibXML::Attr"; 
            break;
        case XML_DOCUMENT_NODE:
        case XML_HTML_DOCUMENT_NODE:
            name = "XML::LibXML::Document";
            break;
        case XML_DOCUMENT_FRAG_NODE:
            name = "XML::LibXML::DocumentFragment";
            break;
        case XML_NAMESPACE_DECL:
            name = "XML::LibXML::Namespace";
            break;
        case XML_DTD_NODE:
            name = "XML::LibXML::Dtd";
            break;
        case XML_PI_NODE:
            name = "XML::LibXML::PI";
            break;
        default:
            name = "XML::LibXML::Node";
            break;
        };
        return name;
    }
    return "";
}

/*
 * @node: Reference to the node the structure proxies
 * @owner: libxml defines only the document, but not the node owner
 *         (in case of document fragments, they are not the same!)
 * @count: this is the internal reference count!
 *
 * Since XML::LibXML will not know, is a certain node is already
 * defined in the perl layer, it can't shurely tell when a node can be
 * safely be removed from the memory. This structure helps to keep
 * track how intense the nodes of a document are used and will not
 * delete the nodes unless they are not refered from somewhere else.
 */
struct _ProxyNode {
    xmlNodePtr node;
    xmlNodePtr owner;
    int count;
    int encoding;
};

/* helper type for the proxy structure */
typedef struct _ProxyNode ProxyNode;

/* pointer to the proxy structure */
typedef ProxyNode* ProxyNodePtr;

/* this my go only into the header used by the xs */
#define SvPROXYNODE(x) ((ProxyNodePtr)SvIV(SvRV(x)))
#define SvNAMESPACE(x) ((xmlNsPtr)SvIV(SvRV(x)))

#define x_PmmREFCNT(node)      node->count
#define x_PmmREFCNT_inc(node)  node->count++
#define x_PmmNODE(thenode)     thenode->node
#define x_PmmOWNER(node)       node->owner
#define x_PmmOWNERPO(node)     ((node && x_PmmOWNER(node)) ? (ProxyNodePtr)x_PmmOWNER(node)->_private : node)

/* creates a new proxy node from a given node. this function is aware
 * about the fact that a node may already has a proxy structure.
 */
ProxyNodePtr
x_PmmNewNode(xmlNodePtr node)
{
    ProxyNodePtr proxy;

    if ( node->_private == NULL ) {
        Newc(0, proxy, 1, ProxyNode, ProxyNode);
        if (proxy != NULL) {
            proxy->node  = node;
            proxy->owner   = NULL;
            proxy->count   = 0;
            proxy->encoding = 0;
            node->_private = (void*) proxy;
        }
    }
    else {
        proxy = (ProxyNodePtr)node->_private;
    }
    return proxy;
}

ProxyNodePtr
x_PmmNewFragment(xmlDocPtr doc) 
{
    ProxyNodePtr retval;
    xmlNodePtr frag = NULL;

    xs_warn("new frag\n");
    frag   = xmlNewDocFragment( doc );
    retval = x_PmmNewNode(frag);

    if ( doc ) {
        xs_warn("inc document\n");
        x_PmmREFCNT_inc(((ProxyNodePtr)doc->_private));
        retval->owner = (xmlNodePtr)doc;
    }

    return retval;
}

/* frees the node if nessecary. this method is aware, that libxml2
 * has several diffrent nodetypes.
 */
void
x_PmmFreeNode( xmlNodePtr node )
{
    switch( node->type ) {
    case XML_DOCUMENT_NODE:
    case XML_HTML_DOCUMENT_NODE:
        xs_warn("XML_DOCUMENT_NODE\n");
        xmlFreeDoc( (xmlDocPtr) node );
        break;
    case XML_ATTRIBUTE_NODE:
        xs_warn("XML_ATTRIBUTE_NODE\n");
        if ( node->parent == NULL ) {
            xs_warn( "free node\n");
            node->ns = NULL;
            xmlFreeProp( (xmlAttrPtr) node );
        }
        break;
    case XML_DTD_NODE:
        if ( node->doc ) {
            if ( node->doc->extSubset != (xmlDtdPtr)node 
                 && node->doc->intSubset != (xmlDtdPtr)node ) {
                xs_warn( "XML_DTD_NODE\n");
                node->doc = NULL;
                xmlFreeDtd( (xmlDtdPtr)node );
            }
        }
        break;
    case XML_DOCUMENT_FRAG_NODE:
        xs_warn("XML_DOCUMENT_FRAG_NODE\n");
    default:
        xmlFreeNode( node);
        break;
    }
}

/* decrements the proxy counter. if the counter becomes zero or less,
   this method will free the proxy node. If the node is part of a
   subtree, PmmREFCNT_def will fix the reference counts and delete
   the subtree if it is not required any more.
 */
int
x_PmmREFCNT_dec( ProxyNodePtr node ) 
{ 
    xmlNodePtr libnode;
    ProxyNodePtr owner; 
    int retval = 0;
    if ( node ) {
        retval = x_PmmREFCNT(node)--;
        if ( x_PmmREFCNT(node) <= 0 ) {
            xs_warn( "NODE DELETATION\n" );
            libnode = x_PmmNODE( node );
            libnode->_private = NULL;
            x_PmmNODE( node ) = NULL;
            if ( x_PmmOWNER(node) && x_PmmOWNERPO(node) ) {
                xs_warn( "DOC NODE!\n" );
                owner = x_PmmOWNERPO(node);
                x_PmmOWNER( node ) = NULL;
                if ( libnode->parent == NULL ) {
                    /* this is required if the node does not directly
                     * belong to the document tree
                     */
                    xs_warn( "REAL DELETE" );
                    x_PmmFreeNode( libnode );
                }            
                x_PmmREFCNT_dec( owner );
            }
            else {
                xs_warn( "STANDALONE REAL DELETE" );
                x_PmmFreeNode( libnode );
            }
            Safefree( node );
        }
    }
    return retval;
}

/* @node: the node that should be wrapped into a SV
 * @owner: perl instance of the owner node (may be NULL)
 *
 * This function will create a real perl instance of a given node.
 * the function is called directly by the XS layer, to generate a perl
 * instance of the node. All node reference counts are updated within
 * this function. Therefore this function returns a node that can
 * directly be used as output.
 *
 * if @ower is NULL or undefined, the node is ment to be the root node
 * of the tree. this node will later be used as an owner of other
 * nodes.
 */
SV*
x_PmmNodeToSv( xmlNodePtr node, ProxyNodePtr owner ) 
{
    ProxyNodePtr dfProxy= NULL;
    SV * retval = &PL_sv_undef;
    const char * CLASS = "XML::LibXML::Node";

    if ( node != NULL ) {
        /* find out about the class */
        CLASS = x_PmmNodeTypeName( node );
        xs_warn(" return new perl node\n");
        xs_warn( CLASS );

        if ( node->_private ) {
            dfProxy = x_PmmNewNode(node);
        }
        else {
            dfProxy = x_PmmNewNode(node);
            if ( dfProxy != NULL ) {
                if ( owner != NULL ) {
                    dfProxy->owner = x_PmmNODE( owner );
                    x_PmmREFCNT_inc( owner );
                }
                else {
                   xs_warn("node contains himself");
                }
            }
            else {
                xs_warn("proxy creation failed!\n");
            }
        }

        retval = NEWSV(0,0);
        sv_setref_pv( retval, CLASS, (void*)dfProxy );
        x_PmmREFCNT_inc(dfProxy);            
    }         
    else {
        xs_warn( "no node found!" );
    }

    return retval;
}

/* extracts the libxml2 node from a perl reference
 */
xmlNodePtr
x_PmmSvNode( SV* perlnode ) 
{
    xmlNodePtr retval = NULL;

    if ( perlnode != NULL
         && perlnode != &PL_sv_undef
         && sv_derived_from(perlnode, "XML::LibXML::Node")
         && SvPROXYNODE(perlnode) != NULL  ) {
        retval = x_PmmNODE( SvPROXYNODE(perlnode) ) ;
    }

    return retval;
}

