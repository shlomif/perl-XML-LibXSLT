/* $Id$ */

#ifdef __cplusplus
extern "C" {
#endif
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include <libxslt/xslt.h>
#include <libxslt/xsltInternals.h>
#include <libxslt/transform.h>
#include <libxslt/xsltutils.h>
#ifdef __cplusplus
}
#endif

SV * debug_cb;

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

void
free_all_callbacks(void)
{
    if (debug_cb) {
        SvREFCNT_dec(debug_cb);
    }
}

int
iowrite_scalar(void * context, const char * buffer, int len)
{
    SV * scalar;
    
    scalar = (SV *)context;

    sv_catpvn(scalar, (char*)buffer, len);
    
    return 0;
}

int
ioclose_scalar(void * context)
{
    return 0;
}

int
iowrite_fh(void * context, const char * buffer, int len)
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
    PUSHs(tbuff);
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
ioclose_fh(void * context)
{
    return 0; /* we let Perl close the FH */
}

void
error_handler(void * ctxt, const char * msg, ...)
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
debug_handler(void * ctxt, const char * msg, ...)
{
    dSP;
    
    SV * tbuff;
    va_list args;
    char buffer[50000];
    
    buffer[0] = 0;
    
    va_start(args, msg);
    vsprintf(&buffer[strlen(buffer)], msg, args);
    va_end(args);

    if (debug_cb && SvTRUE(debug_cb)) {
        int cnt = 0;
        SV * tbuff = newSVpv((char*)buffer, 0);
    
        ENTER;
        SAVETMPS;

        PUSHMARK(SP);
        EXTEND(SP, 1);
        PUSHs(tbuff);
        PUTBACK;

        cnt = perl_call_sv(debug_cb, G_SCALAR);

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
    xsltSetGenericErrorFunc(PerlIO_stderr(), (xmlGenericErrorFunc)error_handler);
    xsltSetGenericDebugFunc(PerlIO_stderr(), (xmlGenericErrorFunc)debug_handler);

void
END()
    CODE:
        free_all_callbacks();

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
            SET_CB(debug_cb, ST(1));
        }
        else {
            RETVAL = debug_cb ? sv_2mortal(debug_cb) : &PL_sv_undef;
        }
    OUTPUT:
        RETVAL

xsltStylesheetPtr
parse_stylesheet(self, doc)
        SV * self
        xmlDocPtr doc
    PREINIT:
        char * CLASS = "XML::LibXSLT::Stylesheet";
        SV ** value;
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

void
add_param(self, param)
        xsltStylesheetPtr self
        const char * param
    CODE:
        xsltParseGlobalParam(self, xmlNewText(param));

xmlDocPtr
transform(self, doc)
        xsltStylesheetPtr self
        xmlDocPtr doc
    PREINIT:
        char * CLASS = "XML::LibXML::Document";
    CODE:
        if (doc == NULL) {
            XSRETURN_UNDEF;
        }
        RETVAL = xsltApplyStylesheet(self, doc);
        if (RETVAL == NULL) {
            XSRETURN_UNDEF;
        }
    OUTPUT:
        RETVAL

xmlDocPtr
transform_file(self, filename)
        xsltStylesheetPtr self
        char * filename
    PREINIT:
        char * CLASS = "XML::LibXML::Document";
    CODE:
        RETVAL = xsltApplyStylesheet(self, xmlParseFile(filename));
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
    CODE:
        output = xmlOutputBufferCreateIO( 
            (xmlOutputWriteCallback) iowrite_scalar,
            (xmlOutputCloseCallback) ioclose_scalar,
            (void*)results,
            NULL
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
    CODE:
        output = xmlOutputBufferCreateIO( 
            (xmlOutputWriteCallback) iowrite_fh,
            (xmlOutputCloseCallback) ioclose_fh,
            (void*)fh,
            NULL
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
