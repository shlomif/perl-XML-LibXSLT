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
    func = hv_fetch(real_obj, "_ext_ent_func", 13, 0);
    
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
    return 1;
}

void * input_open(char const * filename)
{
    SV * f;
    
    f = newSVpv((char*)filename, 0);
    
    return (void*)f;
}

int input_read(void * context, char * buffer, int len)
{
}

void input_close(void * context)
{
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
    
    value = hv_fetch(real_obj, "input_callback", 14, 0);
    if (value && SvTRUE(*value)) {
        /* warn("setting input callback\n"); */
        xmlRegisterInputCallbacks(
                (xmlInputMatchCallback)input_match,
                (xmlInputOpenCallback)input_open,
                (xmlInputReadCallback)input_read,
                (xmlInputCloseCallback)input_close
            );
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
                xmlParseChunk(ctxt, chars, res, 0);
		while ((res = fread(chars, 1, BUFSIZE, f)) > 0) {
		    xmlParseChunk(ctxt, chars, res, 0);
		}
		xmlParseChunk(ctxt, chars, 0, 1);
		RETVAL = ctxt->myDoc;
		ret = ctxt->wellFormed;
		if (!ret) {
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

