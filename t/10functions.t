use Test;
BEGIN { plan tests => 5 }
use XML::LibXSLT;

my $parser = XML::LibXML->new();
my $xslt = XML::LibXSLT->new();
ok($parser); ok($xslt);

$xslt->register_function('urn:foo' => 'test', sub { ok(1); "Foo!" });

my $source = $parser->parse_string(<<'EOT');
<?xml version="1.0" encoding="ISO-8859-1"?>
<document></document>
EOT

my $style = $parser->parse_string(<<'EOT');
<xsl:stylesheet 
    version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:foo="urn:foo"
>

<xsl:template match="/">
  (( <xsl:value-of select="foo:test()"/> ))
</xsl:template>

</xsl:stylesheet>
EOT

ok($style);
my $stylesheet = $xslt->parse_stylesheet($style);

my $results = $stylesheet->transform($source);
ok($results);

print $stylesheet->output_string($results), "\n";
