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
    dSP;
    
    SV * self = (SV *)ctxt;
    SV * tbuff;
    SV ** func;
    va_list args;
    char buffer[50000];
    int cnt;
    
    buffer[0] = 0;
    
    va_start(args, msg);
    vsprintf(&buffer[strlen(buffer)], msg, args);
    va_end(args);
    
    func = hv_fetch((HV *)SvRV(self), "_error_handler", 14, 0);
    
    if (!func || !SvTRUE(*func)) {
        return;
    }
    
    tbuff = newSVpv((char*)buffer, 0);
    
    ENTER;
    SAVETMPS;
    
    PUSHMARK(SP);
    EXTEND(SP, 1);
    PUSHs(tbuff);
    PUTBACK;
    
    cnt = perl_call_sv(*func, G_SCALAR);
    
    SPAGAIN;
    
    if (cnt != 1) {
        croak("error handler call failed");
    }
    
    PUTBACK;
    
    FREETMPS;
    LEAVE;
}

void
setup_parser(SV * self)
{
    SV ** value;
    HV * real_obj = (HV *)SvRV(self);
    
    value = hv_fetch(real_obj, "error_handler", 13, 0);
    if (value && SvTRUE(*value)) {
        xsltSetGenericErrorFunc((void*)self, (xmlGenericErrorFunc)error_handler);
    }
    else {
        xsltSetGenericErrorFunc((void*)self, (xmlGenericErrorFunc)xsltGenericError);
    }
    
    value = hv_fetch(real_obj, "max_depth", 9, 0);
    if (value && SvTRUE(*value)) {
        xsltMaxDepth = SvIV(*value);
    }
    else {
        xsltMaxDepth = 250;
    }
}

MODULE = XML::LibXSLT         PACKAGE = XML::LibXSLT

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
        setup_parser(self);
        RETVAL = xsltParseStylesheetDoc(doc);
        if (RETVAL == NULL) {
            XSRETURN_UNDEF;
        }
    OUTPUT:
        RETVAL


MODULE = XML::LibXSLT         PACKAGE = XML::LibXSLT::Stylesheet

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
