use Test;
BEGIN { plan tests => 4 }
END { ok(0) unless $loaded }
use XML::LibXSLT;
$loaded = 1;
ok(1);

my $p = XML::LibXSLT->new();
ok($p);

ok(XML::LibXSLT::LIBXSLT_VERSION, XML::LibXSLT::LIBXSLT_RUNTIME_VERSION);
ok(XML::LibXML::LIBXML_VERSION, XML::LibXML::LIBXML_RUNTIME_VERSION);

warn "\n\nCompiled against:",
     "\n  libxslt ",XML::LibXSLT::LIBXSLT_VERSION,
       ", libxml2 ",XML::LibXML::LIBXML_VERSION,
     "\nRunning: ",
     "\n  libxslt ",XML::LibXSLT::LIBXSLT_RUNTIME_VERSION,
       ", libxml2 ",XML::LibXML::LIBXML_RUNTIME_VERSION,
     "\n\n";

if (XML::LibXSLT::LIBXSLT_VERSION != XML::LibXSLT::LIBXSLT_RUNTIME_VERSION
    or    
    XML::LibXML::LIBXML_VERSION != XML::LibXML::LIBXML_RUNTIME_VERSION	
    ) {
   warn "DO NOT REPORT THIS FAILURE: Your setup of library paths is incorrect!\n\n";
}
