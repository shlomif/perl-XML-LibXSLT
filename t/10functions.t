use Test;
BEGIN { plan tests => 14 }
use XML::LibXSLT;

my $parser = XML::LibXML->new();
my $xslt = XML::LibXSLT->new();
ok($parser); ok($xslt);

$xslt->register_function('urn:foo' => 'test', sub { ok(1); defined $_[1] ? return $_[0] . $_[1] : return $_[0] });
$xslt->register_function('urn:foo' => 'test2', sub { ok(ref($_[0]), 'XML::LibXML::NodeList'); ref($_[0]) });
$xslt->register_function('urn:foo' => 'test3', sub { ok(@_ == 0); return; });

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
<xsl:variable name="FOO"><xsl:call-template name="Foo"/></xsl:variable>
<xsl:template name="Foo"/>

<xsl:template match="/">
  (( <xsl:value-of select="foo:test('Foo', '!')"/> ))
  (( <xsl:value-of select="foo:test('Foo', '!')"/> ))
       <!-- this works -->
     <xsl:value-of select="foo:test(string($FOO))"/>   
       <!-- this only works in 1.52 -->
     <xsl:value-of select="foo:test($FOO)"/>
  [[ <xsl:value-of select="foo:test2(/*)"/> ]]
  [[ <xsl:value-of select="foo:test2(/*)"/> ]]
  (( <xsl:value-of select="foo:test3()"/> ))
  (( <xsl:value-of select="foo:test3()"/> ))
</xsl:template>

</xsl:stylesheet>
EOT

ok($style);
my $stylesheet = $xslt->parse_stylesheet($style);

my $results = $stylesheet->transform($source);
ok($results);

ok($stylesheet->output_string($results), qr(Foo!));
ok($stylesheet->output_string($results), qr(NodeList));

print $stylesheet->output_string($results), "\n";
