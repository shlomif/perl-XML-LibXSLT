/* $Id$ */

#ifdef __cplusplus
extern "C" {
#endif
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include <libxml/xmlmemory.h>
#include <libxml/parser.h>
#include <libxml/parserInternals.h>
#include <libxml/HTMLparser.h>
#include <libxml/HTMLtree.h>
#include <libxml/tree.h>
#include <libxml/xpath.h>
#include <libxml/debugXML.h>
#include <libxml/xmlerror.h>
#include <libxml/xinclude.h>
#ifdef __cplusplus
}
#endif

#define BUFSIZE 32768

#ifdef VMS
extern int xmlDoValidityCheckingDefaultVal;
#define xmlDoValidityCheckingDefaultValue xmlDoValidityCheckingDefaultVal
extern int xmlSubstituteEntitiesDefaultVal;
#define xmlSubstituteEntitiesDefaultValue xmlSubstituteEntitiesDefaultVal
#else
extern int xmlDoValidityCheckingDefaultValue;
extern int xmlSubstituteEntitiesDefaultValue;
#endif
extern int xmlGetWarningsDefaultValue;
extern int xmlKeepBlanksDefaultValue;
extern int xmlLoadExtDtdDefaultValue;
extern int xmlPedanticParserDefaultValue;

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

SV * LibXML_match_cb = NULL;
SV * LibXML_read_cb = NULL;
SV * LibXML_open_cb = NULL;
SV * LibXML_close_cb = NULL;
SV * LibXML_error = NULL;

void
LibXML_free_all_callbacks(void)
{
    if (LibXML_match_cb) {
        SvREFCNT_dec(LibXML_match_cb);
    }
    
    if (LibXML_read_cb) {
        SvREFCNT_dec(LibXML_read_cb);
    }
    
    if (LibXML_open_cb) {
        SvREFCNT_dec(LibXML_open_cb);
    }
    
    if (LibXML_close_cb) {
        SvREFCNT_dec(LibXML_close_cb);
    }

}

xmlParserInputPtr
LibXML_load_external_entity(
        const char * URL, 
        const char * ID, 
        xmlParserCtxtPtr ctxt)
{
    SV * self;
    HV * real_obj;
    SV ** func;
    int count;
    SV * results;
    STRLEN results_len;
    const char * results_pv;
    xmlParserInputBufferPtr input_buf;
    
    if (ctxt->_private == NULL) {
        return xmlNewInputFromFile(ctxt, URL);
    }
    
    self = (SV *)ctxt->_private;
    real_obj = (HV *)SvRV(self);
    func = hv_fetch(real_obj, "ext_ent_handler", 15, 0);
    
    if (func) {
        dSP;
        
        ENTER;
        SAVETMPS;

        PUSHMARK(SP) ;
        XPUSHs(sv_2mortal(newSVpv((char*)URL, 0)));
        XPUSHs(sv_2mortal(newSVpv((char*)ID, 0)));
        PUTBACK;
        
        count = perl_call_sv(*func, G_SCALAR);
        
        SPAGAIN;
        
        if (!count) {
            croak("external entity handler did not return a value");
        }
        
        results = POPs;
        
        results_pv = SvPV(results, results_len);
        input_buf = xmlParserInputBufferCreateMem(
                        results_pv,
                        results_len,
                        XML_CHAR_ENCODING_NONE
                        );
        
        FREETMPS;
        LEAVE;
        
        return xmlNewIOInputStream(ctxt, input_buf, XML_CHAR_ENCODING_NONE);
    }
    else {
        if (URL == NULL) {
            return NULL;
        }
        return xmlNewInputFromFile(ctxt, URL);
    }
    
}

int 
LibXML_input_match(char const * filename)
{
    int results = 0;
    
    if (LibXML_match_cb && SvTRUE(LibXML_match_cb)) {
        int count;
        SV * res;

        dSP;

        ENTER;
        SAVETMPS;

        PUSHMARK(SP);
        EXTEND(SP, 1);
        PUSHs(sv_2mortal(newSVpv((char*)filename, 0)));
        PUTBACK;

        count = perl_call_sv(LibXML_match_cb, G_SCALAR);

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
LibXML_input_open(char const * filename)
{
    SV * results;
    
    if (LibXML_open_cb && SvTRUE(LibXML_open_cb)) {
        int count;

        dSP;

        ENTER;
        SAVETMPS;

        PUSHMARK(SP);
        EXTEND(SP, 1);
        PUSHs(sv_2mortal(newSVpv((char*)filename, 0)));
        PUTBACK;

        count = perl_call_sv(LibXML_open_cb, G_SCALAR);

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
LibXML_input_read(void * context, char * buffer, int len)
{
    SV * results = NULL;
    STRLEN res_len = 0;
    const char * output;
    
    SV * ctxt = (SV *)context;
    
    if (LibXML_read_cb && SvTRUE(LibXML_read_cb)) {
        int count;

        dSP;

        ENTER;
        SAVETMPS;

        PUSHMARK(SP);
        EXTEND(SP, 2);
        PUSHs(ctxt);
        PUSHs(sv_2mortal(newSViv(len)));
        PUTBACK;

        count = perl_call_sv(LibXML_read_cb, G_SCALAR);

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
LibXML_input_close(void * context)
{
    SV * ctxt = (SV *)context;
    
    if (LibXML_close_cb && SvTRUE(LibXML_close_cb)) {
        int count;

        dSP;

        ENTER;
        SAVETMPS;

        PUSHMARK(SP);
        EXTEND(SP, 1);
        PUSHs(ctxt);
        PUTBACK;

        count = perl_call_sv(LibXML_close_cb, G_SCALAR);

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

void
LibXML_error_handler(void * ctxt, const char * msg, ...)
{
    va_list args;
    char buffer[50000];
    
    buffer[0] = 0;
    
    va_start(args, msg);
    vsprintf(&buffer[strlen(buffer)], msg, args);
    va_end(args);
    
    sv_catpv(LibXML_error, buffer);
/*    croak(buffer); */
}

void
LibXML_validity_error(void * ctxt, const char * msg, ...)
{
    va_list args;
    char buffer[50000];
    
    buffer[0] = 0;
    
    va_start(args, msg);
    vsprintf(&buffer[strlen(buffer)], msg, args);
    va_end(args);
    
    sv_catpv(LibXML_error, buffer);
/*    croak(buffer); */
}

void
LibXML_validity_warning(void * ctxt, const char * msg, ...)
{
    va_list args;
    char buffer[50000];
    
    buffer[0] = 0;
    
    va_start(args, msg);
    vsprintf(&buffer[strlen(buffer)], msg, args);
    va_end(args);
    
    warn(buffer);
}

xmlParserCtxtPtr
LibXML_get_context(SV * self)
{
    SV ** ctxt_sv;
    ctxt_sv = hv_fetch((HV *)SvRV(self), "_context", 8, 0);
    if (!ctxt_sv) {
        croak("cannot fetch context!");
    }
    return (xmlParserCtxtPtr)SvIV((SV*)SvRV(*ctxt_sv));
}

xmlDocPtr
LibXML_parse_stream(SV * self, SV * ioref)
{
    dSP;
    
    xmlDocPtr doc;
    xmlParserCtxtPtr ctxt;
    int well_formed;
    
    SV * tbuff;
    SV * tsize;
    
    int done = 0;
    
    ENTER;
    SAVETMPS;
    
    tbuff = newSV(0);
    tsize = newSViv(BUFSIZE);
    
    ctxt = LibXML_get_context(self);
    
    while (!done) {
        int cnt;
        SV * read_results;
        STRLEN read_length;
        char * chars;
        
        SAVETMPS;
        
        PUSHMARK(SP);
        EXTEND(SP, 3);
        PUSHs(ioref);
        PUSHs(tbuff);
        PUSHs(tsize);
        PUTBACK;
        
        cnt = perl_call_method("read", G_SCALAR);
        
        SPAGAIN;
        
        if (cnt != 1) {
            croak("read method call failed");
        }
        
        read_results = POPs;
        
        if (!SvOK(read_results)) {
            croak("read error");
        }
        
        read_length = SvIV(read_results);
        
        chars = SvPV(tbuff, read_length);
        
        if (read_length > 0) {
            if (read_length == BUFSIZE) {
                xmlParseChunk(ctxt, chars, read_length, 0);
            }
            else {
                xmlParseChunk(ctxt, chars, read_length, 1);
                done = 1;
            }
        }
        else {
            done = 1;
        }
        
        PUTBACK;
        
        FREETMPS;
    }
    
    doc = ctxt->myDoc;
    well_formed = ctxt->wellFormed;
    
    FREETMPS;
    LEAVE;
    
    if (!well_formed) {
        xmlFreeDoc(doc);
        return NULL;
    }
    
    return doc;
}

MODULE = XML::LibXML         PACKAGE = XML::LibXML

PROTOTYPES: DISABLE

BOOT:
    LIBXML_TEST_VERSION
    xmlInitParser();
    xmlRegisterInputCallbacks(
            (xmlInputMatchCallback)LibXML_input_match,
            (xmlInputOpenCallback)LibXML_input_open,
            (xmlInputReadCallback)LibXML_input_read,
            (xmlInputCloseCallback)LibXML_input_close
        );
    xmlSubstituteEntitiesDefaultValue = 1;
    xmlKeepBlanksDefaultValue = 1;
    xmlSetExternalEntityLoader((xmlExternalEntityLoader)LibXML_load_external_entity);
    xmlSetGenericErrorFunc(PerlIO_stderr(), (xmlGenericErrorFunc)LibXML_error_handler);
    LibXML_error = newSVpv("", 0);
    xmlGetWarningsDefaultValue = 0;
    xmlLoadExtDtdDefaultValue = 1;

void
END()
    CODE:
        LibXML_free_all_callbacks();
        xmlCleanupParser();
        SvREFCNT_dec(LibXML_error);

SV *
match_callback(self, ...)
        SV * self
    CODE:
        if (items > 1) {
            SET_CB(LibXML_match_cb, ST(1));
        }
        else {
            RETVAL = LibXML_match_cb ? sv_2mortal(LibXML_match_cb) : &PL_sv_undef;
        }
    OUTPUT:
        RETVAL

SV *
open_callback(self, ...)
        SV * self
    CODE:
        if (items > 1) {
            SET_CB(LibXML_open_cb, ST(1));
        }
        else {
            RETVAL = LibXML_open_cb ? sv_2mortal(LibXML_open_cb) : &PL_sv_undef;
        }
    OUTPUT:
        RETVAL

SV *
read_callback(self, ...)
        SV * self
    CODE:
        if (items > 1) {
            SET_CB(LibXML_read_cb, ST(1));
        }
        else {
            RETVAL = LibXML_read_cb ? sv_2mortal(LibXML_read_cb) : &PL_sv_undef;
        }
    OUTPUT:
        RETVAL

SV *
close_callback(self, ...)
        SV * self
    CODE:
        if (items > 1) {
            SET_CB(LibXML_close_cb, ST(1));
        }
        else {
            RETVAL = LibXML_close_cb ? sv_2mortal(LibXML_close_cb) : &PL_sv_undef;
        }
    OUTPUT:
        RETVAL

int
validation(self, ...)
        SV * self
    CODE:
        RETVAL = xmlDoValidityCheckingDefaultValue;
        if (items > 1) {
            xmlDoValidityCheckingDefaultValue = SvTRUE(ST(1)) ? 1 : 0;
        }
    OUTPUT:
        RETVAL

int
expand_entities(self, ...)
        SV * self
    CODE:
        RETVAL = xmlSubstituteEntitiesDefaultValue;
        if (items > 1) {
            xmlSubstituteEntitiesDefaultValue = SvTRUE(ST(1)) ? 1 : 0;
        }
    OUTPUT:
        RETVAL

int
keep_blanks(self, ...)
        SV * self
    CODE:
        RETVAL = xmlKeepBlanksDefaultValue;
        if (items > 1) {
            xmlKeepBlanksDefaultValue = SvTRUE(ST(1)) ? 1 : 0;
        }
    OUTPUT:
        RETVAL

int
pedantic_parser(self, ...)
        SV * self
    CODE:
        RETVAL = xmlPedanticParserDefaultValue;
        if (items > 1) {
            xmlPedanticParserDefaultValue = SvTRUE(ST(1)) ? 1 : 0;
        }
    OUTPUT:
        RETVAL

int
load_ext_dtd(self, ...)
        SV * self
    CODE:
        RETVAL = xmlLoadExtDtdDefaultValue;
        if (items > 1) {
            xmlLoadExtDtdDefaultValue = SvTRUE(ST(1)) ? 1 : 0;
        }
    OUTPUT:
        RETVAL

void
_prepare(self)
        SV * self
    PREINIT:
        xmlParserCtxtPtr ctxt;
        SV * ctxt_sv;
    CODE:
        sv_setpvn(LibXML_error, "", 0);
        ctxt = xmlCreatePushParserCtxt(NULL, NULL, "", 0, NULL);
        ctxt->_private = (void*)self;
        ctxt_sv = NEWSV(0, 0);
        sv_setref_pv(ctxt_sv, "XML::LibXML::Context", (void*)ctxt);
        hv_store((HV *)SvRV(self), "_context", 8, ctxt_sv, 0);

void
_release(self)
        SV * self
    PREINIT:
        xmlParserCtxtPtr ctxt;
        SV * hval;
    CODE:
        hval = hv_delete((HV *)SvRV(self), "_context", 8, 0);
        ctxt = (xmlParserCtxtPtr)SvIV( (SV*)SvRV(hval) );

char *
get_last_error(CLASS)
        char * CLASS
    PREINIT:
        STRLEN len;
    CODE:
        RETVAL = SvPV(LibXML_error, len);
    OUTPUT:
        RETVAL

xmlDocPtr
_parse_string(self, string)
        SV * self
        SV * string
    PREINIT:
        xmlParserCtxtPtr ctxt;
        char * CLASS = "XML::LibXML::Document";
        STRLEN len;
        char * ptr;
        int well_formed;
    CODE:
        ptr = SvPV(string, len);
        ctxt = LibXML_get_context(self);
        xmlParseChunk(ctxt, ptr, len, 0);
        xmlParseChunk(ctxt, ptr, 0, 1);
        well_formed = ctxt->wellFormed;
        RETVAL = ctxt->myDoc;
        if (!well_formed) {
            xmlFreeDoc(RETVAL);
            croak(SvPV(LibXML_error, len));
        }
    OUTPUT:
        RETVAL

xmlDocPtr
_parse_fh(self, fh)
        SV * self
        SV * fh
    PREINIT:
        char * CLASS = "XML::LibXML::Document";
        STRLEN len;
    CODE:
        RETVAL = LibXML_parse_stream(self, fh);
        if (RETVAL == NULL) {
            croak(SvPV(LibXML_error, len));
        }
    OUTPUT:
        RETVAL
        
xmlDocPtr
_parse_file(self, filename)
        SV * self
        const char * filename
    PREINIT:
        xmlParserCtxtPtr ctxt;
        char * CLASS = "XML::LibXML::Document";
        PerlIO *f;
        int ret;
        int res;
        STRLEN len;
        char chars[BUFSIZE];
    CODE:
        if ((filename[0] == '-') && (filename[1] == 0)) {
	    f = PerlIO_stdin();
	} else {
	    f = PerlIO_open(filename, "r");
	}
	if (f != NULL) {
            ctxt = LibXML_get_context(self);
	    res = PerlIO_read(f, chars, 4);
	    if (res > 0) {
                xmlParseChunk(ctxt, chars, res, 0);
		while ((res = PerlIO_read(f, chars, BUFSIZE)) > 0) {
		    xmlParseChunk(ctxt, chars, res, 0);
		}
                xmlParseChunk(ctxt, chars, 0, 1);
		RETVAL = ctxt->myDoc;
		ret = ctxt->wellFormed;
		if (!ret) {
                    PerlIO_close(f);
		    xmlFreeDoc(RETVAL);
		    croak(SvPV(LibXML_error, len));
		}
	    }
            PerlIO_close(f);
	}
        else {
            croak("cannot open file %s", filename);
        }
    OUTPUT:
        RETVAL


MODULE = XML::LibXML         PACKAGE = XML::LibXML::Document

void
DESTROY(self)
        xmlDocPtr self
    CODE:
        if (self == NULL) {
            XSRETURN_UNDEF;
        }
        if (self->standalone == 42) {
            XSRETURN_UNDEF;
        }
        xmlFreeDoc(self);

SV *
toString(self)
        xmlDocPtr self
    PREINIT:
        xmlChar *result;
        int len;
    CODE:
        xmlDocDumpMemory(self, &result, &len);
	if (result == NULL) {
	    croak("Failed to convert doc to string");
	} else {
            RETVAL = newSVpvn((char *)result, (STRLEN)len);
	    xmlFree(result);
	}
    OUTPUT:
        RETVAL

int
is_valid(self, ...)
        xmlDocPtr self
    PREINIT:
        xmlValidCtxt cvp;
        xmlDtdPtr dtd;
        SV * dtd_sv;
    CODE:
        if (items > 1) {
            dtd_sv = ST(1);
            if ( sv_isobject(dtd_sv) && (SvTYPE(SvRV(dtd_sv)) == SVt_PVMG) ) {
                dtd = (xmlDtdPtr)SvIV((SV*)SvRV( dtd_sv ));
            }
            else {
                croak("is_valid: argument must be a DTD object");
            }
            cvp.userData = (void*)PerlIO_stderr();
            cvp.error = (xmlValidityErrorFunc)LibXML_validity_error;
            cvp.warning = (xmlValidityWarningFunc)LibXML_validity_warning;
            RETVAL = xmlValidateDtd(&cvp, self, dtd);
        }
        else {
            RETVAL = xmlValidateDocument(&cvp, self);
        }
    OUTPUT:
        RETVAL

void
process_xinclude(self)
        xmlDocPtr self
    CODE:
        xmlXIncludeProcess(self);


MODULE = XML::LibXML         PACKAGE = XML::LibXML::Context

void
DESTROY(self)
        xmlParserCtxtPtr self
    CODE:
        xmlFreeParserCtxt(self);

MODULE = XML::LibXML         PACKAGE = XML::LibXML::Dtd

xmlDtdPtr
new(CLASS, external, system)
        char * CLASS
        char * external
        char * system
    CODE:
        RETVAL = xmlParseDTD((const xmlChar*)external, (const xmlChar*)system);
    OUTPUT:
        RETVAL
