use Test;
BEGIN { plan tests => 3 }
END { ok(0) unless $loaded }
use XML::LibXSLT;
$loaded = 1;
ok(1);

my $p = XML::LibXSLT->new();
ok($p);

ok(XML::LibXSLT::LIBXSLT_VERSION, XML::LibXSLT::LIBXSLT_RUNTIME_VERSION);

warn "\n\nCompiled against libxslt version: ",XML::LibXSLT::LIBXSLT_VERSION,
     "\nRunning libxml2 version:          ",XML::LibXSLT::LIBXSLT_RUNTIME_VERSION,
     "\n\n";

if (XML::LibXSLT::LIBXSLT_VERSION != XML::LibXSLT::LIBXSLT_RUNTIME_VERSION) {
   warn "DO NOT REPORT THIS FAILURE: Your setup of library paths is incorrect!\n\n";
}
