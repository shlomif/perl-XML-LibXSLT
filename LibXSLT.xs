/* $Id$ */

#ifdef __cplusplus
extern "C" {
#endif
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include <libxml/xmlversion.h>
#include <libxml/xmlmemory.h>
#include <libxml/debugXML.h>
#include <libxml/HTMLtree.h>
#include <libxml/tree.h>
#include <libxslt/xslt.h>
#include <libxslt/xsltInternals.h>
#include <libxslt/transform.h>
#include <libxslt/xsltutils.h>
#include <libxslt/imports.h>
#ifdef HAVE_EXSLT
#include <libexslt/exslt.h>
#include <libexslt/exsltconfig.h>
#endif
#ifdef __cplusplus
}
#endif

#define SET_CB(cb, fld) \
    RETVAL = cb ? newSVsv(cb) : &PL_sv_undef;\
    if (SvOK(fld)) {\
        if (cb) {\
            if (cb != fld) {\
                sv_setsv(cb, fld);\
            }\
        }\
        else {\
            cb = newSVsv(fld);\
        }\
    }\
    else {\
        if (cb) {\
            SvREFCNT_dec(cb);\
            cb = NULL;\
        }\
    }

static SV * LibXSLT_match_cb = NULL;
static SV * LibXSLT_read_cb = NULL;
static SV * LibXSLT_open_cb = NULL;
static SV * LibXSLT_close_cb = NULL;
static SV * LibXSLT_debug_cb = NULL;

typedef struct _ProxyObject ProxyObject;

struct _ProxyObject {
    void * object;
    SV * extra;
};

ProxyObject *
LibXSLT_make_proxy_node (xmlDocPtr node)
{
    ProxyObject * proxy;
    
    proxy = (ProxyObject*)New(0, proxy, 1, ProxyObject);
    if (proxy != NULL) {
        proxy->object = (void*)node;
        proxy->extra = NULL;
    }
    return proxy;
}

void
LibXSLT_free_all_callbacks(void)
{
    if (LibXSLT_debug_cb) {
        SvREFCNT_dec(LibXSLT_debug_cb);
    }
}

int 
LibXSLT_input_match(char const * filename)
{
    int results = 0;
    
    if (LibXSLT_match_cb && SvTRUE(LibXSLT_match_cb)) {
        int count;
        SV * res;

        dSP;

        ENTER;
        SAVETMPS;

        PUSHMARK(SP);
        EXTEND(SP, 1);
        PUSHs(sv_2mortal(newSVpv((char*)filename, 0)));
        PUTBACK;

        count = perl_call_sv(LibXSLT_match_cb, G_SCALAR);

        SPAGAIN;
        
        if (count != 1) {
            croak("match callback must return a single value");
        }
        
        res = POPs;

        if (SvTRUE(res)) {
            results = 1;
        }
        
        PUTBACK;
        FREETMPS;
        LEAVE;
    }
    
    return results;
}

void * 
LibXSLT_input_open(char const * filename)
{
    SV * results;

    if (LibXSLT_open_cb && SvTRUE(LibXSLT_open_cb)) {
        int count;

        dSP;

        ENTER;
        SAVETMPS;

        PUSHMARK(SP);
        EXTEND(SP, 1);
        PUSHs(sv_2mortal(newSVpv((char*)filename, 0)));
        PUTBACK;

        count = perl_call_sv(LibXSLT_open_cb, G_SCALAR);

        SPAGAIN;
        
        if (count != 1) {
            croak("open callback must return a single value");
        }

        results = POPs;

        SvREFCNT_inc(results);

        PUTBACK;
        FREETMPS;
        LEAVE;
    }
    
    return (void *)results;
}

int 
LibXSLT_input_read(void * context, char * buffer, int len)
{
    SV * results = NULL;
    STRLEN res_len = 0;
    const char * output;
    
    SV * ctxt = (SV *)context;
    
    if (LibXSLT_read_cb && SvTRUE(LibXSLT_read_cb)) {
        int count;

        dSP;

        ENTER;
        SAVETMPS;

        PUSHMARK(SP);
        EXTEND(SP, 2);
        PUSHs(ctxt);
        PUSHs(sv_2mortal(newSViv(len)));
        PUTBACK;

        count = perl_call_sv(LibXSLT_read_cb, G_SCALAR);

        SPAGAIN;
        
        if (count != 1) {
            croak("read callback must return a single value");
        }

        output = POPp;
        if (output != NULL) {
            res_len = strlen(output);
            if (res_len) {
                strncpy(buffer, output, res_len);
            }
            else {
                buffer[0] = 0;
            }
        }
        
        FREETMPS;
        LEAVE;
    }
    
    /* warn("read, asked for: %d, returning: [%d] %s\n", len, res_len, buffer); */
    return res_len;
}

void 
LibXSLT_input_close(void * context)
{
    SV * ctxt = (SV *)context;
    
    if (LibXSLT_close_cb && SvTRUE(LibXSLT_close_cb)) {
        int count;

        dSP;

        ENTER;
        SAVETMPS;

        PUSHMARK(SP);
        EXTEND(SP, 1);
        PUSHs(ctxt);
        PUTBACK;

        count = perl_call_sv(LibXSLT_close_cb, G_SCALAR);

        SPAGAIN;

        SvREFCNT_dec(ctxt);
        
        if (!count) {
            croak("close callback failed");
        }

        PUTBACK;
        FREETMPS;
        LEAVE;
    }
}

int
LibXSLT_iowrite_scalar(void * context, const char * buffer, int len)
{
    SV * scalar;
    
    scalar = (SV *)context;

    sv_catpvn(scalar, (char*)buffer, len);
    
    return len;
}

int
LibXSLT_ioclose_scalar(void * context)
{
    return 0;
}

int
LibXSLT_iowrite_fh(void * context, const char * buffer, int len)
{
    dSP;
    
    SV * ioref;
    SV * tbuff;
    SV * results;
    int cnt;
    
    ENTER;
    SAVETMPS;
    
    ioref = (SV *)context;
    
    tbuff = newSVpvn((char*)buffer, len);

    PUSHMARK(SP);
    EXTEND(SP, 2);
    PUSHs(ioref);
    PUSHs(sv_2mortal(tbuff));
    PUTBACK;
    
    cnt = perl_call_method("print", G_SCALAR);
    
    SPAGAIN;
    
    if (cnt != 1) {
        croak("fh->print() method call failed");
    }
    
    results = POPs;
    
    if (!SvOK(results)) {
        croak("print to fh failed");
    }
    
    PUTBACK;
    
    FREETMPS;
    LEAVE;
    
    return len;
}

int
LibXSLT_ioclose_fh(void * context)
{
    return 0; /* we let Perl close the FH */
}

void
LibXSLT_error_handler(void * ctxt, const char * msg, ...)
{
    va_list args;
    SV * sv;
    STRLEN n_a;
    
    sv = NEWSV(0,512);

    va_start(args, msg);
    sv_vsetpvfn(sv, msg, strlen(msg), &args, NULL, 0, NULL);
    va_end(args);

    sv_2mortal(sv);
    croak(SvPV(sv, n_a));
}

void
LibXSLT_debug_handler(void * ctxt, const char * msg, ...)
{
    dSP;
    
    va_list args;
    SV * sv;
    STRLEN n_a;
    
    sv = NEWSV(0,512);

    va_start(args, msg);
    sv_vsetpvfn(sv, msg, strlen(msg), &args, NULL, 0, NULL);
    va_end(args);

    if (LibXSLT_debug_cb && SvTRUE(LibXSLT_debug_cb)) {
        int cnt = 0;
    
        ENTER;
        SAVETMPS;

        PUSHMARK(SP);
        EXTEND(SP, 1);
        PUSHs(sv);
        PUTBACK;

        cnt = perl_call_sv(LibXSLT_debug_cb, G_SCALAR);

        SPAGAIN;

        if (cnt != 1) {
            croak("debug handler call failed");
        }

        PUTBACK;

        FREETMPS;
        LEAVE;
    }
    
    SvREFCNT_dec(sv);
}

void
LibXSLT_set_callbacks()
{
    xmlRegisterInputCallbacks(LibXSLT_input_match,
                    LibXSLT_input_open,
                    LibXSLT_input_read,
                    LibXSLT_input_close);
    if (LibXSLT_debug_cb) {
        xsltSetGenericDebugFunc(PerlIO_stderr(), (xmlGenericErrorFunc)LibXSLT_debug_handler);
    }
    xsltSetGenericErrorFunc(PerlIO_stderr(), (xmlGenericErrorFunc)LibXSLT_error_handler);
}

void
LibXSLT_unset_callbacks()
{
    xmlRegisterInputCallbacks(NULL, NULL, NULL, NULL);
    xsltSetGenericDebugFunc(NULL, NULL);
    xsltSetGenericErrorFunc(NULL, NULL);
}

MODULE = XML::LibXSLT         PACKAGE = XML::LibXSLT

PROTOTYPES: DISABLE

BOOT:
    LIBXML_TEST_VERSION
    xsltMaxDepth = 250;
    LibXSLT_debug_cb = NULL;
    LibXSLT_match_cb = NULL;
    LibXSLT_open_cb = NULL;
    LibXSLT_read_cb = NULL;
    LibXSLT_close_cb = NULL;
#ifdef HAVE_EXSLT
    exsltRegisterAll();
#endif

void
END()
    CODE:
        LibXSLT_free_all_callbacks();

int
max_depth(self, ...)
        SV * self
    CODE:
        RETVAL = xsltMaxDepth;
        if (items > 1) {
            xsltMaxDepth = SvIV(ST(1));
        }
    OUTPUT:
        RETVAL

SV *
debug_callback(self, ...)
        SV * self
    CODE:
        if (items > 1) {
            SV * debug_cb = ST(1);
            if (debug_cb && SvTRUE(debug_cb)) {
                SET_CB(LibXSLT_debug_cb, ST(1));
            }
            else {
                LibXSLT_debug_cb = NULL;
            }
        }
        else {
            RETVAL = LibXSLT_debug_cb ? sv_2mortal(LibXSLT_debug_cb) : &PL_sv_undef;
        }
    OUTPUT:
        RETVAL

SV *
match_callback(self, ...)
        SV * self
    CODE:
        if (items > 1) {
            SV * match_cb = ST(1);
            if (match_cb && SvTRUE(match_cb)) {
                SET_CB(LibXSLT_match_cb, ST(1));
            }
            else {
                LibXSLT_match_cb = NULL;
            }
        }
        else {
            RETVAL = LibXSLT_match_cb ? sv_2mortal(LibXSLT_match_cb) : &PL_sv_undef;
        }
    OUTPUT:
        RETVAL

SV *
read_callback(self, ...)
        SV * self
    CODE:
        if (items > 1) {
            SV * read_cb = ST(1);
            if (read_cb && SvTRUE(read_cb)) {
                SET_CB(LibXSLT_read_cb, ST(1));
            }
            else {
                LibXSLT_read_cb = NULL;
            }
        }
        else {
            RETVAL = LibXSLT_read_cb ? sv_2mortal(LibXSLT_read_cb) : &PL_sv_undef;
        }
    OUTPUT:
        RETVAL

SV *
open_callback(self, ...)
        SV * self
    CODE:
        if (items > 1) {
            SV * open_cb = ST(1);
            if (open_cb && SvTRUE(open_cb)) {
                SET_CB(LibXSLT_open_cb, ST(1));
            }
            else {
                LibXSLT_open_cb = NULL;
            }
        }
        else {
            RETVAL = LibXSLT_open_cb ? sv_2mortal(LibXSLT_open_cb) : &PL_sv_undef;
        }
    OUTPUT:
        RETVAL

SV *
close_callback(self, ...)
        SV * self
    CODE:
        if (items > 1) {
            SV * close_cb = ST(1);
            if (close_cb && SvTRUE(close_cb)) {
                SET_CB(LibXSLT_close_cb, ST(1));
            }
            else {
                LibXSLT_close_cb = NULL;
            }
        }
        else {
            RETVAL = LibXSLT_close_cb ? sv_2mortal(LibXSLT_close_cb) : &PL_sv_undef;
        }
    OUTPUT:
        RETVAL

xsltStylesheetPtr
parse_stylesheet(self, doc)
        SV * self
        xmlDocPtr doc
    PREINIT:
        char * CLASS = "XML::LibXSLT::Stylesheet";
        xmlDocPtr doc_copy;
    CODE:
        if (doc == NULL) {
            XSRETURN_UNDEF;
        }
        doc_copy = xmlCopyDoc(doc, 1);
        doc_copy->URL = xmlStrdup(doc->URL);
        LibXSLT_set_callbacks();
        RETVAL = xsltParseStylesheetDoc(doc_copy);
        LibXSLT_unset_callbacks();
        if (RETVAL == NULL) {
            XSRETURN_UNDEF;
        }
    OUTPUT:
        RETVAL

xsltStylesheetPtr
parse_stylesheet_file(self, filename)
        SV * self
        const char * filename
    PREINIT:
        char * CLASS = "XML::LibXSLT::Stylesheet";
    CODE:
        LibXSLT_set_callbacks();
        RETVAL = xsltParseStylesheetFile(filename);
        LibXSLT_unset_callbacks();
        if (RETVAL == NULL) {
            XSRETURN_UNDEF;
        }
    OUTPUT:
        RETVAL

MODULE = XML::LibXSLT         PACKAGE = XML::LibXSLT::Stylesheet

PROTOTYPES: DISABLE

ProxyObject *
transform(self, doc, ...)
        xsltStylesheetPtr self
        xmlDocPtr doc
    PREINIT:
        char * CLASS = "XML::LibXML::Document";
        # note really only 254 entries here - last one is NULL
        const char *xslt_params[255];
        xmlDocPtr real_dom;
    CODE:
        if (doc == NULL) {
            XSRETURN_UNDEF;
        }
        xslt_params[0] = 0;
        if (items > 256) {
            croak("Too many parameters in transform()");
        }
        if (items % 2) {
            croak("Odd number of parameters");
        }
        if (items > 2) {
            int i;
            for (i = 2; (i < items && i < 256); i++) {
                xslt_params[i - 2] = (char *)SvPV(ST(i), PL_na);
            }
            # set last entry to NULL
            xslt_params[i - 2] = 0;
        }
        LibXSLT_set_callbacks();
        real_dom = xsltApplyStylesheet(self, doc, xslt_params);
        LibXSLT_unset_callbacks();
        if (real_dom == NULL) {
            XSRETURN_UNDEF;
        }
        if (real_dom->type == XML_HTML_DOCUMENT_NODE) {
            if (self->method != NULL) {
                xmlFree(self->method);
            }
            self->method = xmlMalloc(5);
            strcpy(self->method, "html");
        }
        RETVAL = LibXSLT_make_proxy_node(real_dom);
    OUTPUT:
        RETVAL

ProxyObject *
transform_file(self, filename, ...)
        xsltStylesheetPtr self
        char * filename
    PREINIT:
        char * CLASS = "XML::LibXML::Document";
        # note really only 254 entries here - last one is NULL
        const char *xslt_params[255];
        xmlDocPtr real_dom;
    CODE:
        xslt_params[0] = 0;
        if (items > 256) {
            croak("Too many parameters in transform()");
        }
        if (items % 2) {
            croak("Odd number of parameters");
        }
        if (items > 2) {
            int i;
            for (i = 2; (i < items && i < 256); i++) {
                xslt_params[i - 2] = (char *)SvPV(ST(i), PL_na);
            }
            # set last entry to NULL
            xslt_params[i - 2] = 0;
        }
        LibXSLT_set_callbacks();
        real_dom = xsltApplyStylesheet(self, xmlParseFile(filename), xslt_params);
        LibXSLT_unset_callbacks();
        if (real_dom == NULL) {
            XSRETURN_UNDEF;
        }
        if (real_dom->type == XML_HTML_DOCUMENT_NODE) {
            if (self->method != NULL) {
                xmlFree(self->method);
            }
            self->method = xmlMalloc(5);
            strcpy(self->method, "html");
        }
        RETVAL = LibXSLT_make_proxy_node(real_dom);
    OUTPUT:
        RETVAL

void
DESTROY(self)
        xsltStylesheetPtr self
    CODE:
        if (self == NULL) {
            XSRETURN_UNDEF;
        }
        xsltFreeStylesheet(self);

SV *
output_string(self, doc)
        xsltStylesheetPtr self
        xmlDocPtr doc
    PREINIT:
        xmlOutputBufferPtr output;
        SV * results = newSVpv("", 0);
        const xmlChar *encoding = NULL;
	xmlCharEncodingHandlerPtr encoder = NULL;
    CODE:
        XSLT_GET_IMPORT_PTR(encoding, self, encoding)
        if (encoding != NULL) {
            encoder = xmlFindCharEncodingHandler((char *)encoding);
	    if ((encoder != NULL) &&
                 (xmlStrEqual((const xmlChar *)encoder->name,
                              (const xmlChar *) "UTF-8")))
                encoder = NULL;
        }
        output = xmlOutputBufferCreateIO( 
            (xmlOutputWriteCallback) LibXSLT_iowrite_scalar,
            (xmlOutputCloseCallback) LibXSLT_ioclose_scalar,
            (void*)results,
            encoder
            );
        if (xsltSaveResultTo(output, doc, self) == -1) {
            croak("output to scalar failed");
        }
        xmlOutputBufferClose(output);
        RETVAL = results;
    OUTPUT:
        RETVAL

void
output_fh(self, doc, fh)
        xsltStylesheetPtr self
        xmlDocPtr doc
        SV * fh
    PREINIT:
        xmlOutputBufferPtr output;
        const xmlChar *encoding = NULL;
	xmlCharEncodingHandlerPtr encoder = NULL;
    CODE:
        XSLT_GET_IMPORT_PTR(encoding, self, encoding)
        if (encoding != NULL) {
            encoder = xmlFindCharEncodingHandler((char *)encoding);
	    if ((encoder != NULL) &&
                 (xmlStrEqual((const xmlChar *)encoder->name,
                              (const xmlChar *) "UTF-8")))
                encoder = NULL;
        }
        output = xmlOutputBufferCreateIO( 
            (xmlOutputWriteCallback) LibXSLT_iowrite_fh,
            (xmlOutputCloseCallback) LibXSLT_ioclose_fh,
            (void*)fh,
            encoder
            );
        if (xsltSaveResultTo(output, doc, self) == -1) {
            croak("output to fh failed");
        }
        xmlOutputBufferClose(output);
        
void
output_file(self, doc, filename)
        xsltStylesheetPtr self
        xmlDocPtr doc
        char * filename
    CODE:
        xsltSaveResultToFilename(filename, doc, self, 0);

char *
media_type(self)
        xsltStylesheetPtr self
    CODE:
        RETVAL = (char *)self->mediaType;
        if (RETVAL == NULL) {
            /* OK, that was borked. Try finding xsl:output tag manually... */
            xmlNodePtr child;
            child = self->doc->children->children;
            while ( child != NULL && 
                    strcmp(child->name, "output") != 0 &&
                    child->ns && child->ns->href &&
                    strcmp(child->ns->href, 
                    "http://www.w3.org/1999/XSL/Transform") != 0) {
                child = child->next;
            }
            
            if (child != NULL) {
                 RETVAL = xmlGetProp(child, "media-type");
            }
            
            if (RETVAL == NULL) {
                RETVAL = "text/xml";
                /* this below is rather simplistic, but should work for most cases */
                if (self->method != NULL) {
                    if (strcmp(self->method, "html") == 0) {
                        RETVAL = "text/html";
                    }
                    else if (strcmp(self->method, "text") == 0) {
                        RETVAL = "text/plain";
                    }
                }
            }
        }
    OUTPUT:
        RETVAL

char *
output_encoding(self)
        xsltStylesheetPtr self
    CODE:
        RETVAL = (char *)self->encoding;
        if (RETVAL == NULL) {
            RETVAL = "UTF-8";
        }
    OUTPUT:
        RETVAL
