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
#else
extern int xmlDoValidityCheckingDefaultValue;
#endif
extern int xmlGetWarningsDefaultValue;

SV * global_ctxt;

xmlParserInputPtr load_external_entity(
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
            croak("Big trouble!");
        }
        
        results = POPs;
        
        PUTBACK;
        FREETMPS;
        LEAVE;
        
        results_pv = SvPV(results, results_len);
        input_buf = xmlParserInputBufferCreateMem(
                        results_pv,
                        results_len,
                        XML_CHAR_ENCODING_NONE
                        );
        
        return xmlNewIOInputStream(ctxt, input_buf, XML_CHAR_ENCODING_NONE);
    }
    return NULL;
}

int input_match(char const * filename)
{
    HV * real_obj;
    SV ** value;
    HV * callback_vector;
    int results = 0;
    
    real_obj = (HV *)SvRV(global_ctxt);

    value = hv_fetch(real_obj, "input_callbacks", 14, 0);
    if (value && SvTRUE(*value)) {
        callback_vector = (HV *)SvRV(*value);
        value = hv_fetch(callback_vector, "match", 5, 0);
        if (value && SvTRUE(*value)) {
            int count;
            
            dSP;

            ENTER;
            SAVETMPS;

            PUSHMARK(SP);
            EXTEND(SP, 1);
            PUSHs(sv_2mortal(newSVpv((char*)filename, 0)));
            PUTBACK;

            count = perl_call_sv(*value, G_SCALAR);

            SPAGAIN;

            if (!count) {
                croak("Big trouble!");
            }

            if (SvTRUE(POPs)) {
                results = 1;
            }

            PUTBACK;
            FREETMPS;
            LEAVE;
        }
        else {
            croak("match function must be defined!");
        }
    }
    
    return results;
}

void * input_open(char const * filename)
{
    HV * real_obj;
    SV ** value;
    HV * callback_vector;
    SV * results;
    
    real_obj = (HV *)SvRV(global_ctxt);

    value = hv_fetch(real_obj, "input_callbacks", 14, 0);
    if (value && SvTRUE(*value)) {
        callback_vector = (HV *)SvRV(*value);
        value = hv_fetch(callback_vector, "open", 4, 0);
        if (value && SvTRUE(*value)) {
            int count;
            
            dSP;

            ENTER;
            SAVETMPS;

            PUSHMARK(SP);
            EXTEND(SP, 1);
            PUSHs(sv_2mortal(newSVpv((char*)filename, 0)));
            PUTBACK;

            count = perl_call_sv(*value, G_SCALAR);

            SPAGAIN;

            if (!count) {
                croak("Big trouble!");
            }

            results = POPs;

            PUTBACK;
            FREETMPS;
            LEAVE;
        }
        else {
            croak("open function must be defined!");
        }
    }
    
    return (void *)results;
}

int input_read(void * context, char * buffer, int len)
{
    HV * real_obj;
    SV ** value;
    HV * callback_vector;
    SV * results = newSVpvn("", 0);
    int res_len = 0;
    
    SV * ctxt;
    
    ctxt = (SV*)context;
    
    real_obj = (HV *)SvRV(global_ctxt);

    value = hv_fetch(real_obj, "input_callbacks", 14, 0);
    if (value && SvTRUE(*value)) {
        callback_vector = (HV *)SvRV(*value);
        value = hv_fetch(callback_vector, "read", 4, 0);
        if (value && SvTRUE(*value)) {
            int count;
            
            dSP;

            ENTER;
            SAVETMPS;

            PUSHMARK(SP);
            EXTEND(SP, 2);
            PUSHs(ctxt);
            PUSHs(sv_2mortal(newSViv(len)));
            PUTBACK;

            count = perl_call_sv(*value, G_SCALAR);

            SPAGAIN;

            if (!count) {
                croak("Big trouble!");
            }

            results = POPs;

            PUTBACK;
            FREETMPS;
            LEAVE;
        }
        else {
            croak("read function must be defined!");
        }
    }
    
    buffer = SvPV(results, res_len);
    
    return res_len;
}

void input_close(void * context)
{
    HV * real_obj;
    SV ** value;
    HV * callback_vector;
    SV * ctxt = (SV*)context;
    
    real_obj = (HV *)SvRV(global_ctxt);

    value = hv_fetch(real_obj, "input_callbacks", 14, 0);
    if (value && SvTRUE(*value)) {
        callback_vector = (HV *)SvRV(*value);
        value = hv_fetch(callback_vector, "close", 4, 0);
        if (value && SvTRUE(*value)) {
            int count;
            
            dSP;

            ENTER;
            SAVETMPS;

            PUSHMARK(SP);
            EXTEND(SP, 1);
            PUSHs(ctxt);
            PUTBACK;

            count = perl_call_sv(*value, G_SCALAR);

            SPAGAIN;

            if (!count) {
                croak("Big trouble!");
            }

            PUTBACK;
            FREETMPS;
            LEAVE;
        }
        else {
            croak("close function must be defined!");
        }
    }
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
    HV * real_obj;
    SV ** value;
    
    real_obj = (HV *)SvRV(self);
    
    xmlInitParser();
    
    /* entity expansion */
    value = hv_fetch(real_obj, "no_entities", 11, 0);
    if (value && SvTRUE(*value)) {
        /* warn("no entities\n"); */
        xmlSubstituteEntitiesDefault(0);
    }
    else {
        /* warn("entities\n"); */
        xmlSubstituteEntitiesDefault(1);
    }
    
    /* validation ? */
    value = hv_fetch(real_obj, "validate", 8, 0);
    if (value && SvTRUE(*value)) {
        /* warn("validate\n"); */
        xmlDoValidityCheckingDefaultValue = 1;
    }
    else {
        /* warn("don't validate\n"); */
        xmlDoValidityCheckingDefaultValue = 0;
    }
    
    /* entity loader */
    value = hv_fetch(real_obj, "ext_ent_handler", 15, 0);
    if (value && SvTRUE(*value)) {
        /* warn("setting external entity loader\n"); */
        xmlSetExternalEntityLoader( 
            (xmlExternalEntityLoader) load_external_entity 
            );
    }
    
    /* input callbacks */
    value = hv_fetch(real_obj, "input_callbacks", 14, 0);
    if (value && SvTRUE(*value)) {
        /* warn("setting input callback\n"); */
        global_ctxt = self;
        xmlRegisterInputCallbacks(
                (xmlInputMatchCallback)input_match,
                (xmlInputOpenCallback)input_open,
                (xmlInputReadCallback)input_read,
                (xmlInputCloseCallback)input_close
            );
    }
    
    /* error handler */
    value = hv_fetch(real_obj, "error_handler", 13, 0);
    if (value && SvTRUE(*value)) {
        xmlSetGenericErrorFunc((void*)self, (xmlGenericErrorFunc)error_handler);
    }
    
    /* lose blanks */
    value = hv_fetch(real_obj, "lose_blanks", 11, 0);
    if (value && SvTRUE(*value)) {
        /* warn("setting keepBlanksDefault(0)\n"); */
        xmlKeepBlanksDefault(0);
    }
    else {
        /* warn("setting keepBlanksDefault(1)\n"); */
        xmlKeepBlanksDefault(1);
    }
}

xmlDocPtr
parse_stream(SV * self, SV * ioref)
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
    
    setup_parser(self);
    
    ctxt = xmlCreatePushParserCtxt(NULL, NULL, "", 0, NULL);
    ctxt->_private = (void*)self;

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
        xmlFreeParserCtxt(ctxt);
        xmlFreeDoc(doc);
        return NULL;
    }
    
    xmlFreeParserCtxt(ctxt);
    
    return doc;
}

MODULE = XML::LibXML         PACKAGE = XML::LibXML

PROTOTYPES: DISABLE

xmlDocPtr
parse_string(self, string)
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
        setup_parser(self);
        ctxt = xmlCreatePushParserCtxt(NULL, NULL, "", 0, NULL);
        ctxt->_private = (void*)self;
        if(xmlParseChunk(ctxt, ptr, len, 0)) {
            croak("parse failed");
        }
        xmlParseChunk(ctxt, ptr, 0, 1);
        well_formed = ctxt->wellFormed;
        RETVAL = ctxt->myDoc;
        xmlFreeParserCtxt(ctxt);
        if (!well_formed) {
            xmlFreeDoc(RETVAL);
            croak("Not well formed!");
        }
    OUTPUT:
        RETVAL

xmlDocPtr
parse_fh(self, fh)
        SV * self
        SV * fh
    PREINIT:
        char * CLASS = "XML::LibXML::Document";
    CODE:
        RETVAL = parse_stream(self, fh);
    OUTPUT:
        RETVAL
        
xmlDocPtr
parse_file(self, filename)
        SV * self
        const char * filename
    PREINIT:
        xmlParserCtxtPtr ctxt;
        char * CLASS = "XML::LibXML::Document";
        FILE *f;
        int ret;
        int res;
        char chars[BUFSIZE];
    CODE:
        if ((filename[0] == '-') && (filename[1] == 0)) {
	    f = stdin;
	} else {
	    f = fopen(filename, "r");
	}
	if (f != NULL) {
            setup_parser(self);
            ctxt = xmlCreatePushParserCtxt(NULL, NULL, "", 0, NULL);
            ctxt->_private = (void*)self;
	    res = fread(chars, 1, 4, f);
	    if (res > 0) {
                if (xmlParseChunk(ctxt, chars, res, 0)) {
                    xmlFreeParserCtxt(ctxt);
                    croak("parse failed");
                }
		while ((res = fread(chars, 1, BUFSIZE, f)) > 0) {
		    if (xmlParseChunk(ctxt, chars, res, 0)) {
                        xmlFreeParserCtxt(ctxt);
                        croak("parse failed");
                    }
		}
                if (xmlParseChunk(ctxt, chars, 0, 1)) {
                    xmlFreeParserCtxt(ctxt);
                    croak("parse failed");
                }
		RETVAL = ctxt->myDoc;
		ret = ctxt->wellFormed;
		if (!ret) {
                    xmlFreeParserCtxt(ctxt);
		    xmlFreeDoc(RETVAL);
                    fclose(f);
		    XSRETURN_UNDEF;
		}
	    }
            fclose(f);
            xmlFreeParserCtxt(ctxt);
	}
        else {
            XSRETURN_UNDEF;
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
        xmlCleanupParser();

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
            RETVAL = newSVpvn(result, len);
	    xmlFree(result);
	}
    OUTPUT:
        RETVAL

# todo: add optional DTD file
SV *
is_valid(self)
        xmlDocPtr self
    PREINIT:
        xmlValidCtxt cvp;
    CODE:
        if (!xmlValidateDocument(&cvp, self)) {
            XSRETURN_UNDEF;
        }
        else {
            RETVAL = newSViv(1);
        }
    OUTPUT:
        RETVAL

void
process_xinclude(self)
        xmlDocPtr self
    CODE:
        xmlXIncludeProcess(self);

