use strict;                     # -*- perl -*-
use Test;
BEGIN { plan tests => 7; }

use XML::LibXSLT;
use XML::LibXML;

my $parser = XML::LibXML->new();
ok( $parser );

# U+0100 == LATIN CAPITAL LETTER A WITH MACRON
my $doc = $parser->parse_string(<<XML);
<unicode>\x{0100}dam</unicode>
XML
ok( $doc );

my $xslt = XML::LibXSLT->new();
my $style_doc = $parser->parse_string(<<XSLT);
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="text" encoding="UTF-8"/>
  <xsl:template match="/unicode">
    <xsl:value-of select="."/>
  </xsl:template>
</xsl:stylesheet>
XSLT
ok( $style_doc );

my $stylesheet = $xslt->parse_stylesheet($style_doc);
ok( $stylesheet );

my $results = $stylesheet->transform($doc);
ok( $results );

my $output = $stylesheet->output_string( $results );
ok( $output );

# Test that we've correctly converted to characters seeing as the
# output format was UTF-8.
ok( $output eq "\x{0100}dam" )
  or warn "# output is [[$output]]\n";

