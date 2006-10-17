use strict;                     # -*- perl -*-
use Test;
BEGIN { plan tests => 32; }

use XML::LibXSLT;
use XML::LibXML;
use Encode;

my $parser = XML::LibXML->new();
ok( $parser );

my $xslt = XML::LibXSLT->new();

{
# U+0100 == LATIN CAPITAL LETTER A WITH MACRON
my $doc = $parser->parse_string(<<XML);
<unicode>\x{0100}dam</unicode>
XML
ok( $doc );

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

ok( Encode::is_utf8($output) );
ok( $output, "\x{0100}dam" );

$output = $stylesheet->output_as_chars( $results );
ok( Encode::is_utf8($output) );
ok( $output, "\x{0100}dam" );

$output = $stylesheet->output_as_bytes( $results );
ok( !Encode::is_utf8($output) );
ok( $output, "\xC4\x80dam" );
}

# LATIN-2 character 17E - z caron
my $doc = $parser->parse_string(<<XML);
<?xml version="1.0" encoding="UTF-8"?>
<unicode>\x{17E}il</unicode>
XML
ok( $doc );

# no encoding: libxslt chooses either an entity or UTF-8
{
  my $style_doc = $parser->parse_string(<<XSLT);
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="text"/>
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
  ok( !Encode::is_utf8($output) );
  ok( $output =~ /^(?:&#382;|\xC5\xBE)il/ );

  $output = $stylesheet->output_as_chars( $results );
  ok( Encode::is_utf8($output) );
  ok( $output, "\x{17E}il" );
  $output = $stylesheet->output_as_bytes( $results );
  ok( !Encode::is_utf8($output) );
  ok( $output =~ /^(?:&#382;|\xC5\xBE)il/ );
}

# doesn't map to latin-1 so will appear as an entity
{
  my $style_doc = $parser->parse_string(<<XSLT);
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="text" encoding="iso-8859-1"/>
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

  ok( !Encode::is_utf8($output) );
  ok( $output, "&#382;il" );

  $output = $stylesheet->output_as_chars( $results );
  ok( Encode::is_utf8($output) );
  ok( $output, "\x{17E}il" );

  $output = $stylesheet->output_as_bytes( $results );
  ok( !Encode::is_utf8($output) );
  ok( $output, "&#382;il" );
}
