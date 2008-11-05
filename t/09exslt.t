use Test;
use constant PLAN => 6;
BEGIN { plan tests => PLAN; }

use XML::LibXSLT;
use XML::LibXML;

unless (XML::LibXSLT::HAVE_EXSLT()) {
  skip("this test requires XML::LibXSLT to be compiled with libexslt\n") for (1..PLAN);	
  exit;
}

my $parser = XML::LibXML->new();
ok($parser);

my $doc = $parser->parse_string(<<'EOT');
<?xml version="1.0"?>

<doc>

</doc>
EOT

ok($doc);

my $xslt = XML::LibXSLT->new();
my $style_doc = $parser->parse_string(<<'EOT');
<?xml version="1.0"?>
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:str="http://exslt.org/strings"
    exclude-result-prefixes="str">

<xsl:template match="/">
<out>;
 str:tokenize('2001-06-03T11:40:23', '-T:')
 <xsl:copy-of select="str:tokenize('2001-06-03T11:40:23', '-T:')"/>;
 str:tokenize('date math str')
 <xsl:copy-of select="str:tokenize('date math str')"/>;
</out>
</xsl:template>

</xsl:stylesheet>
EOT

ok($style_doc);

# warn "Style_doc = \n", $style_doc->toString, "\n";

my $stylesheet = $xslt->parse_stylesheet($style_doc);

ok($stylesheet);

my $results = $stylesheet->transform($doc);

ok($results);

my $output = $stylesheet->output_string($results);

ok($output);

# warn "Results:\n", $output, "\n";
