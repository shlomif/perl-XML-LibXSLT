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
#include <libxslt/xslt.h>
#include <libxslt/xsltInternals.h>
#include <libxslt/transform.h>
#include <libxslt/xsltutils.h>
#include <libxslt/imports.h>
#ifdef __cplusplus
}
#endif

#define SET_CB(cb, fld) \
    RETVAL = cb ? newSVsv(cb) : &PL_sv_undef;\
    if (cb) {\
        if (cb != fld) {\
            sv_setsv(cb, fld);\
        }\
    }\
    else {\
        cb = newSVsv(fld);\
    }

static SV * LibXSLT_debug_cb = NULL;

void
LibXSLT_free_all_callbacks(void)
{
    if (LibXSLT_debug_cb) {
        SvREFCNT_dec(LibXSLT_debug_cb);
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
    char buffer[50000];
    
    buffer[0] = 0;
    
    va_start(args, msg);
    vsprintf(&buffer[strlen(buffer)], msg, args);
    va_end(args);
    
    croak(buffer);
}

void
LibXSLT_debug_handler(void * ctxt, const char * msg, ...)
{
    dSP;
    
    va_list args;
    char buffer[50000];
    
    buffer[0] = 0;

    va_start(args, msg);
    vsprintf(&buffer[strlen(buffer)], msg, args);
    va_end(args);

    if (LibXSLT_debug_cb && SvTRUE(LibXSLT_debug_cb)) {
        int cnt = 0;
        SV * tbuff = newSVpv((char*)buffer, 0);
    
        ENTER;
        SAVETMPS;

        PUSHMARK(SP);
        EXTEND(SP, 1);
        PUSHs(tbuff);
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
    
}

MODULE = XML::LibXSLT         PACKAGE = XML::LibXSLT

BOOT:
    LIBXML_TEST_VERSION
    xsltMaxDepth = 250;
    LibXSLT_debug_cb = NULL;
    xsltSetGenericErrorFunc(PerlIO_stderr(), (xmlGenericErrorFunc)LibXSLT_error_handler);
    xsltSetGenericDebugFunc(PerlIO_stderr(), (xmlGenericErrorFunc)LibXSLT_debug_handler);

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
            SET_CB(LibXSLT_debug_cb, ST(1));
        }
        else {
            RETVAL = LibXSLT_debug_cb ? sv_2mortal(LibXSLT_debug_cb) : &PL_sv_undef;
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
        RETVAL = xsltParseStylesheetDoc(doc_copy);
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
        RETVAL = xsltParseStylesheetFile(filename);
        if (RETVAL == NULL) {
            XSRETURN_UNDEF;
        }
    OUTPUT:
        RETVAL

MODULE = XML::LibXSLT         PACKAGE = XML::LibXSLT::Stylesheet

xmlDocPtr
transform(self, doc, ...)
        xsltStylesheetPtr self
        xmlDocPtr doc
    PREINIT:
        char * CLASS = "XML::LibXML::Document";
        # note really only 254 entries here - last one is NULL
        const char *xslt_params[255];
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
        RETVAL = xsltApplyStylesheet(self, doc, xslt_params);
        if (RETVAL == NULL) {
            XSRETURN_UNDEF;
        }
    OUTPUT:
        RETVAL

xmlDocPtr
transform_file(self, filename, ...)
        xsltStylesheetPtr self
        char * filename
    PREINIT:
        char * CLASS = "XML::LibXML::Document";
        # note really only 254 entries here - last one is NULL
        const char *xslt_params[255];
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
        RETVAL = xsltApplyStylesheet(self, xmlParseFile(filename), xslt_params);
        if (RETVAL == NULL) {
            XSRETURN_UNDEF;
        }
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
