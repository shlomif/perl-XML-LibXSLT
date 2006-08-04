# -*- cperl -*-
use Test;
BEGIN { plan tests => 5 }
END { ok(0) unless $loaded }
use XML::LibXSLT;
$loaded = 1;
ok(1);
my $x = XML::LibXML->new() ;
ok($x) ;
my $p = XML::LibXSLT->new();
ok($p);
my $xsl = <<EOF;
<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 version="1.0"> <xsl:import href="example/2.xsl" />
 <xsl:output method="html" />
</xsl:stylesheet>
EOF

my $xsld = $x->parse_string($xsl) ;
ok($xsld) ;
my $tr = $p->parse_stylesheet($xsld) ;
ok($tr) ;
