/**
 * perl-libxml-mm.h
 * $Id$
 *
 * Basic concept:
 * perl varies in the implementation of UTF8 handling. this header (together
 * with the c source) implements a few functions, that can be used from within
 * the core module inorder to avoid cascades of c pragmas
 */

#ifndef __PERL_LIBXML_MM_H__
#define __PERL_LIBXML_MM_H__

#ifdef __cplusplus
extern "C" {
#endif
#include "EXTERN.h"
#include "perl.h"

#include <libxml/parser.h>

#ifdef __cplusplus
}
#endif

/*
 * NAME xs_warn 
 * TYPE MACRO
 * 
 * this makro is for XML::LibXML development and debugging. 
 *
 * SYNOPSIS
 * xs_warn("my warning")
 *
 * this makro takes only a single string(!) and passes it to perls
 * warn function if the XS_WARNRINGS pragma is used at compile time
 * otherwise any xs_warn call is ignored.
 * 
 * pay attention, that xs_warn does not implement a complete wrapper
 * for warn!!
 */
#ifdef XS_WARNINGS
#define xs_warn(string) warn(string) 
#else
#define xs_warn(string)
#endif

struct _ProxyNode;
typedef struct _ProxyNode ProxyNode;
typedef ProxyNode* ProxyNodePtr;

/* this my go only into the header used by the xs */
#define SvPROXYNODE(x) ((ProxyNodePtr)SvIV(SvRV(x)))

#define x_PmmREFCNT(node)      node->count
#define x_PmmREFCNT_inc(node)  node->count++
#define x_PmmNODE(xnode)       xnode->node
#define x_PmmOWNER(node)       node->owner
#define x_PmmOWNERPO(node)     ((node && x_PmmOWNER(node)) ? (ProxyNodePtr)x_PmmOWNER(node)->_private : node)

ProxyNodePtr
x_PmmNewNode(xmlNodePtr node);

ProxyNodePtr
x_PmmNewFragment(xmlDocPtr document);

int
x_PmmREFCNT_dec( ProxyNodePtr node );

SV*
x_PmmNodeToSv( xmlNodePtr node, ProxyNodePtr owner );

xmlNodePtr
x_PmmSvNode( SV * perlnode );

/**
 * NAME domNodeTypeName
 * TYPE function
 * 
 * returns the perl class name for the given node
 *
 * SYNOPSIS
 * CLASS = domNodeTypeName( node );
 */
const char*
x_PmmNodeTypeName( xmlNodePtr elem );

#endif
