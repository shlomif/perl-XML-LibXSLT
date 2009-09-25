# -*- cperl -*-

use Test;
BEGIN { plan tests => 2 }
use XML::LibXML;
use XML::LibXSLT;

{
  # test for #41542 - DTD subset disappeare
  # in the source document after the transformation
  my $parser = XML::LibXML->new();
  $parser->validation(1);
  $parser->expand_entities(0);
  my $xml = <<'EOT';
<?xml version="1.0" standalone="no"?>
<!DOCTYPE article [
<!ENTITY foo "FOO">
<!ELEMENT article (#PCDATA)>
]>
<article>&foo;</article>
EOT
  my $doc = $parser->parse_string($xml);

  my $xslt = XML::LibXSLT->new();
  $parser->validation(0);
  my $style_doc = $parser->parse_string(<<'EOX');
<?xml version="1.0" encoding="utf-8"?>
<xsl:transform xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
<xsl:template match="/">
<out>hello</out>
</xsl:template>
</xsl:transform>
EOX

  ok($doc->toString() eq $xml);
  $xslt->parse_stylesheet($style_doc)->transform($doc);
  ok($doc->toString() eq $xml);

}
