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

#define PREFIX LibXSLT

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

SV * PREFIX_debug_cb;

void
PREFIX_free_all_callbacks(void)
{
    if (PREFIX_debug_cb) {
        SvREFCNT_dec(PREFIX_debug_cb);
    }
}

int
PREFIX_iowrite_scalar(void * context, const char * buffer, int len)
{
    SV * scalar;
    
    scalar = (SV *)context;

    sv_catpvn(scalar, (char*)buffer, len);
    
    return len;
}

int
PREFIX_ioclose_scalar(void * context)
{
    return 0;
}

int
PREFIX_iowrite_fh(void * context, const char * buffer, int len)
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
PREFIX_ioclose_fh(void * context)
{
    return 0; /* we let Perl close the FH */
}

void
PREFIX_error_handler(void * ctxt, const char * msg, ...)
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
PREFIX_debug_handler(void * ctxt, const char * msg, ...)
{
    dSP;
    
    va_list args;
    char buffer[50000];
    
    buffer[0] = 0;
    
    va_start(args, msg);
    vsprintf(&buffer[strlen(buffer)], msg, args);
    va_end(args);

    if (PREFIX_debug_cb && SvTRUE(PREFIX_debug_cb)) {
        int cnt = 0;
        SV * tbuff = newSVpv((char*)buffer, 0);
    
        ENTER;
        SAVETMPS;

        PUSHMARK(SP);
        EXTEND(SP, 1);
        PUSHs(tbuff);
        PUTBACK;

        cnt = perl_call_sv(PREFIX_debug_cb, G_SCALAR);

        SPAGAIN;

        if (cnt != 1) {
            croak("debug handler call failed");
        }

        PUTBACK;

        FREETMPS;
        LEAVE;
    }
    else {
        xmlGenericError(ctxt, buffer);
    }
    
}

MODULE = XML::LibXSLT         PACKAGE = XML::LibXSLT

BOOT:
    xsltMaxDepth = 250;
    xsltSetGenericErrorFunc(PerlIO_stderr(), (xmlGenericErrorFunc)PREFIX_error_handler);
    xsltSetGenericDebugFunc(PerlIO_stderr(), (xmlGenericErrorFunc)PREFIX_debug_handler);

void
END()
    CODE:
        PREFIX_free_all_callbacks();

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
            SET_CB(PREFIX_debug_cb, ST(1));
        }
        else {
            RETVAL = PREFIX_debug_cb ? sv_2mortal(PREFIX_debug_cb) : &PL_sv_undef;
        }
    OUTPUT:
        RETVAL

xsltStylesheetPtr
parse_stylesheet(self, doc)
        SV * self
        xmlDocPtr doc
    PREINIT:
        char * CLASS = "XML::LibXSLT::Stylesheet";
    CODE:
        if (doc == NULL) {
            XSRETURN_UNDEF;
        }
        doc->standalone = 42;
        RETVAL = xsltParseStylesheetDoc(doc);
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
        const char *xslt_params[254];
    CODE:
        if (doc == NULL) {
            XSRETURN_UNDEF;
        }
        if (items > 2) {
            int i;
            for (i = 2; (i < items && i < 256); i++) {
                xslt_params[i - 2] = (char *)SvPV(ST(i), PL_na);
            }
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
        const char *xslt_params[254];
    CODE:
        if (items > 2) {
            int i;
            for (i = 2; (i < items && i < 256); i++) {
                xslt_params[i - 2] = (char *)SvPV(ST(i), PL_na);
            }
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
            (xmlOutputWriteCallback) PREFIX_iowrite_scalar,
            (xmlOutputCloseCallback) PREFIX_ioclose_scalar,
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
            (xmlOutputWriteCallback) PREFIX_iowrite_fh,
            (xmlOutputCloseCallback) PREFIX_ioclose_fh,
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
