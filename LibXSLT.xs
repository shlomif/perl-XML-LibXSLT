/* $Id$ */

#ifdef __cplusplus
extern "C" {
#endif
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#ifdef __cplusplus
}
#endif

MODULE = XML::LibXSLT         PACKAGE = XML::LibXSLT

void
init(self)
        char * CLASS
    CODE:
        RETVAL = ghttp_request_new();
        if (RETVAL == NULL) {
            warn("Unable to allocate ghttp_request");
            XSRETURN_UNDEF;
        }
        /* sv_bless(RETVAL, gv_stash_pv(CLASS, 1)); */
    OUTPUT:
        RETVAL

void
DESTROY(self)
        ghttp_request *self
    CODE:
        ghttp_request_destroy(self);
