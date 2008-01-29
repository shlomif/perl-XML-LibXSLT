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

#include "perl-libxml-mm.h"

#include "XSUB.h"
#include <libxml/tree.h>

#ifdef __cplusplus
}
#endif

#ifdef XS_WARNINGS
#define xs_warn(string) warn(string) 
/* #define xs_warn(string) fprintf(stderr, string) */
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
 * This is XML::LibXSLT specific:
 *
 * a pointer to XML::LibXML's registry of all current proxy nodes
 */
extern ProxyNodePtr* PROXY_NODE_REGISTRY_PTR;
#define PROXY_NODE_REGISTRY *PROXY_NODE_REGISTRY_PTR

/*
 * @proxy: proxy node to register
 *
 * adds a proxy node to the proxy node registry
 */
void
x_PmmRegisterProxyNode(ProxyNodePtr proxy)
{
  proxy->_registry = PROXY_NODE_REGISTRY;
  PROXY_NODE_REGISTRY = proxy;
}

/*
 * @proxy: proxy node to remove
 *
 * removes a proxy node from the proxy node registry
 */
void
x_PmmUnregisterProxyNode(ProxyNodePtr proxy)
{
    ProxyNodePtr cur = PROXY_NODE_REGISTRY;
    if( PROXY_NODE_REGISTRY == proxy ) {
        PROXY_NODE_REGISTRY = proxy->_registry;
    }
    else if (cur!=NULL) {
        while(cur->_registry != NULL)
        {
            if( cur->_registry == proxy )
            {
                cur->_registry = proxy->_registry;
                break;
            }
            cur = cur->_registry;
        }
    } else {
      warn("XML::LibXSLT: Unregistering a node while no node was registered?");
    }
}

/*
 * increments all proxy node counters by one (called on thread spawn)
 */
void
x_PmmCloneProxyNodes()
{
    ProxyNodePtr cur = PROXY_NODE_REGISTRY;
    while(cur != NULL)
    {
        x_PmmREFCNT_inc(cur);
        cur = cur->_registry;
    }
}

/*
 * returns the current number of proxy nodes in the registry
 */
int
x_PmmProxyNodeRegistrySize()
{
    int i = 0;
    ProxyNodePtr cur = PROXY_NODE_REGISTRY;
    while(cur != NULL)
    {
        ++i;
        cur = cur->_registry;
    }
    return i;
}

/* creates a new proxy node from a given node. this function is aware
 * about the fact that a node may already has a proxy structure.
 */
ProxyNodePtr
x_PmmNewNode(xmlNodePtr node)
{
    ProxyNodePtr proxy = NULL;

    if ( node == NULL ) {
        xs_warn( "x_PmmNewNode: no node found\n" );
        return NULL;
    }

    if ( node->_private == NULL ) {
        /* proxy = (ProxyNodePtr)malloc(sizeof(struct _ProxyNode));  */
        Newc(0, proxy, 1, ProxyNode, ProxyNode);
        if (proxy != NULL) {
            proxy->node  = node;
            proxy->owner   = NULL;
            proxy->count   = 0;
            proxy->encoding= 0;
            proxy->_registry = NULL;
            node->_private = (void*) proxy;
            x_PmmRegisterProxyNode(proxy);
        }
    }
    else {
        proxy = (ProxyNodePtr)node->_private;
	if (proxy->_registry==NULL && PROXY_NODE_REGISTRY!=proxy) {
	  x_PmmRegisterProxyNode(proxy);
	}
    }

    return proxy;
}

ProxyNodePtr
x_PmmNewFragment(xmlDocPtr doc) 
{
    ProxyNodePtr retval = NULL;
    xmlNodePtr frag = NULL;

    xs_warn("x_PmmNewFragment: new frag\n");
    frag   = xmlNewDocFragment( doc );
    retval = x_PmmNewNode(frag);
    /* fprintf(stderr, "REFCNT NOT incremented on frag: 0x%08.8X\n", retval); */

    if ( doc != NULL ) {
        xs_warn("x_PmmNewFragment: inc document\n");
        /* under rare circumstances _private is not set correctly? */
        if ( doc->_private != NULL ) {
            xs_warn("x_PmmNewFragment:   doc->_private being incremented!\n");
            x_PmmREFCNT_inc(((ProxyNodePtr)doc->_private));
            /* fprintf(stderr, "REFCNT incremented on doc: 0x%08.8X\n", doc->_private); */
        }
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
        xs_warn("x_PmmFreeNode: XML_DOCUMENT_NODE\n");
        xmlFreeDoc( (xmlDocPtr) node );
        break;
    case XML_ATTRIBUTE_NODE:
        xs_warn("x_PmmFreeNode: XML_ATTRIBUTE_NODE\n");
        if ( node->parent == NULL ) {
            xs_warn( "x_PmmFreeNode:   free node!\n");
            node->ns = NULL;
            xmlFreeProp( (xmlAttrPtr) node );
        }
        break;
    case XML_DTD_NODE:
        if ( node->doc != NULL ) {
            if ( node->doc->extSubset != (xmlDtdPtr)node 
                 && node->doc->intSubset != (xmlDtdPtr)node ) {
                xs_warn( "x_PmmFreeNode: XML_DTD_NODE\n");
                node->doc = NULL;
                xmlFreeDtd( (xmlDtdPtr)node );
            }
        } else {
            xs_warn( "x_PmmFreeNode: XML_DTD_NODE (no doc)\n");
            xmlFreeDtd( (xmlDtdPtr)node );
        }
        break;
    case XML_DOCUMENT_FRAG_NODE:
        xs_warn("x_PmmFreeNode: XML_DOCUMENT_FRAG_NODE\n");
    default:
        xs_warn( "x_PmmFreeNode: normal node\n" );
        xmlFreeNode( node);
        break;
    }
}

/* decrements the proxy counter. if the counter becomes zero or less,
   this method will free the proxy node. If the node is part of a
   subtree, x_PmmREFCNT_dec will fix the reference counts and delete
   the subtree if it is not required any more.
 */
int
x_PmmREFCNT_dec( ProxyNodePtr node ) 
{ 
    xmlNodePtr libnode = NULL;
    ProxyNodePtr owner = NULL;  
    int retval = 0;

    if ( node != NULL ) {
        retval = x_PmmREFCNT(node)--;
	/* fprintf(stderr, "REFCNT on 0x%08.8X decremented to %d\n", node, x_PmmREFCNT(node)); */
        if ( x_PmmREFCNT(node) < 0 )
            warn( "x_PmmREFCNT_dec: REFCNT decremented below 0!" );
        if ( x_PmmREFCNT(node) <= 0 ) {
            xs_warn( "x_PmmREFCNT_dec: NODE DELETION\n" );

            libnode = x_PmmNODE( node );
            if ( libnode != NULL ) {
                if ( libnode->_private != node ) {
                    xs_warn( "x_PmmREFCNT_dec:   lost node\n" );
                    libnode = NULL;
                }
                else {
                    libnode->_private = NULL;
                }
            }

            x_PmmNODE( node ) = NULL;
            if ( x_PmmOWNER(node) && x_PmmOWNERPO(node) ) {
                xs_warn( "x_PmmREFCNT_dec:   DOC NODE!\n" );
                owner = x_PmmOWNERPO(node);
                x_PmmOWNER( node ) = NULL;
                if( libnode != NULL && libnode->parent == NULL ) {
                    /* this is required if the node does not directly
                     * belong to the document tree
                     */
                    xs_warn( "x_PmmREFCNT_dec:     REAL DELETE\n" );
                    x_PmmFreeNode( libnode );
                }
                xs_warn( "x_PmmREFCNT_dec:   decrease owner\n" );
                x_PmmREFCNT_dec( owner );
            }
            else if ( libnode != NULL ) {
                xs_warn( "x_PmmREFCNT_dec:   STANDALONE REAL DELETE\n" );
                
                x_PmmFreeNode( libnode );
            }
            x_PmmUnregisterProxyNode(node);
            Safefree( node );
            /* free( node ); */
        }
    }
    else {
        xs_warn("x_PmmREFCNT_dec: lost node\n" );
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
        xs_warn("x_PmmNodeToSv: return new perl node of class:\n");
        xs_warn( CLASS );

        if ( node->_private != NULL ) { 
            dfProxy = x_PmmNewNode(node);
            /* warn(" at 0x%08.8X\n", dfProxy); */
        }
        else {
            dfProxy = x_PmmNewNode(node);
            /* fprintf(stderr, " at 0x%08.8X\n", dfProxy); */
            if ( dfProxy != NULL ) {
                if ( owner != NULL ) {
                    dfProxy->owner = x_PmmNODE( owner );
                    x_PmmREFCNT_inc( owner );
                    /* fprintf(stderr, "REFCNT incremented on owner: 0x%08.8X\n", owner); */
                }
                else {
                   xs_warn("x_PmmNodeToSv:   node contains itself (owner==NULL)\n");
                }
            }
            else {
                xs_warn("x_PmmNodeToSv:   proxy creation failed!\n");
            }
        }

        retval = NEWSV(0,0);
        sv_setref_pv( retval, CLASS, (void*)dfProxy );
        x_PmmREFCNT_inc(dfProxy); 
        /* fprintf(stderr, "REFCNT incremented on node: 0x%08.8X\n", dfProxy); */

        switch ( node->type ) {
        case XML_DOCUMENT_NODE:
        case XML_HTML_DOCUMENT_NODE:
        case XML_DOCB_DOCUMENT_NODE:
            if ( ((xmlDocPtr)node)->encoding != NULL ) {
                dfProxy->encoding = (int)xmlParseCharEncoding( (const char*)((xmlDocPtr)node)->encoding );
            }
            break;
        default:
            break;
        }
    }
    else {
        xs_warn( "x_PmmNodeToSv: no node found!\n" );
    }

    return retval;
}


/* extracts the libxml2 node from a perl reference
 */

xmlNodePtr
x_PmmSvNodeExt( SV* perlnode, int copy ) 
{
    xmlNodePtr retval = NULL;
    ProxyNodePtr proxy = NULL;

    if ( perlnode != NULL && perlnode != &PL_sv_undef ) {
/*         if ( sv_derived_from(perlnode, "XML::LibXML::Node") */
/*              && SvPROXYNODE(perlnode) != NULL  ) { */
/*             retval = x_PmmNODE( SvPROXYNODE(perlnode) ) ; */
/*         } */
        xs_warn("x_PmmSvNodeExt: perlnode found\n" );
        if ( sv_derived_from(perlnode, "XML::LibXML::Node")  ) {
            proxy = SvPROXYNODE(perlnode);
            if ( proxy != NULL ) {
                xs_warn( "x_PmmSvNodeExt:   is a xmlNodePtr structure\n" );
                retval = x_PmmNODE( proxy ) ;
            }

            if ( retval != NULL
                 && ((ProxyNodePtr)retval->_private) != proxy ) {
                xs_warn( "x_PmmSvNodeExt:   no node in proxy node\n" );
                x_PmmNODE( proxy ) = NULL;
                retval = NULL;
            }
        }
#ifdef  XML_LIBXML_GDOME_SUPPORT
        else if ( sv_derived_from( perlnode, "XML::GDOME::Node" ) ) {
            GdomeNode* gnode = (GdomeNode*)SvIV((SV*)SvRV( perlnode ));
            if ( gnode == NULL ) {
                warn( "no XML::GDOME data found (datastructure empty)" );    
            }
            else {
                retval = gdome_xml_n_get_xmlNode( gnode );
                if ( retval == NULL ) {
                    xs_warn( "x_PmmSvNodeExt: no XML::LibXML node found in GDOME object\n" );
                }
                else if ( copy == 1 ) {
                    retval = x_PmmCloneNode( retval, 1 );
                }
            }
        }
#endif
    }

    return retval;
}

/* extracts the libxml2 owner node from a perl reference
 */
xmlNodePtr
x_PmmSvOwner( SV* perlnode ) 
{
    xmlNodePtr retval = NULL;
    if ( perlnode != NULL
         && perlnode != &PL_sv_undef
         && SvPROXYNODE(perlnode) != NULL  ) {
        retval = x_PmmOWNER( SvPROXYNODE(perlnode) );
    }
    return retval;
}
