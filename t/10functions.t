use Test;
BEGIN { plan tests => 35 }
use XML::LibXSLT;

{
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

  $xslt->register_function('urn:foo' => 'get_list', \&get_nodelist );

  our @words = qw( one two three );

  sub get_nodelist {
    my $nl = XML::LibXML::NodeList->new();
    $nl -> push( map { XML::LibXML::Text->new($_) } @words );
    return $nl;
  }

  $style = $parser->parse_string(<<'EOT');
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:foo="urn:foo">

  <xsl:template match="/">
      <xsl:for-each select='foo:get_list()'>
        <li><xsl:value-of select='.'/></li>
      </xsl:for-each>
  </xsl:template>

</xsl:stylesheet>
EOT

  ok($style);

  $stylesheet = $xslt->parse_stylesheet($style);
  for (1..5) {
    $results = $stylesheet->transform($source);

    ok($results);
    ok($stylesheet->output_string($results), qr(<li>one</li>));
    ok($stylesheet->output_string($results), qr(<li>one</li><li>two</li><li>three</li>));
  }
}

{
  # testcase by Elizabeth Mattijsen
  my $parser   = XML::LibXML->new;
  my $xsltproc = XML::LibXSLT->new;

  my $xml  = $parser->parse_string( <<'XML' );
<html><head/></html>
XML
  my $xslt = $parser->parse_string( <<'XSLT' );
<xsl:stylesheet
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:foo="http://foo"
  version="1.0">
<xsl:template match="/html">
   <html>
     <xsl:apply-templates/>
   </html>
</xsl:template>
<xsl:template match="/html/head">
  <head>
   <xsl:copy-of select="foo:custom()/foo"/>
   <xsl:apply-templates/>
  </head>
</xsl:template>
</xsl:stylesheet>
XSLT

  my $aux = <<'XML';
<bar>
  <y><foo>1st</foo></y>
  <y><foo>2nd</foo></y>
</bar>
XML
  {
    XML::LibXSLT->register_function(
      ('http://foo', 'custom') => sub { $parser->parse_string( $aux )->findnodes('//y') }
     );
    my $stylesheet = $xsltproc->parse_stylesheet($xslt);
    my $result = $stylesheet->transform($xml);
    # the behavior has changed in some version of libxslt
    my $expect = qq(<html xmlns:foo="http://foo"><head><foo>1st</foo><foo>2nd</foo></head></html>\n);
    ok ($result->serialize,qr{(\Q<?xml version="1.0"?>\n\E)?\Q$expect\E});
  }
  {
    XML::LibXSLT->register_function(
      ('http://foo', 'custom') => sub { $parser->parse_string( $aux )->findnodes('//y')->[0]; });
    my $stylesheet = $xsltproc->parse_stylesheet($xslt);
    my $result = $stylesheet->transform($xml);
    my $expect = qq(<html xmlns:foo="http://foo"><head><foo>1st</foo></head></html>\n);
    ok ($result->serialize,qr{(\Q<?xml version="1.0"?>\n\E)?\Q$expect\E});
  }
}

{
  my $parser   = XML::LibXML->new;
  my $xsltproc = XML::LibXSLT->new;
   my $xslt = $parser->parse_string( <<'XSLT' );
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:x="http://x/x"
  version="1.0">
<xsl:namespace-alias stylesheet-prefix="x" result-prefix="#default"/>
<xsl:template match="/">
   <out>
     <xsl:copy-of select="x:test(.)"/>
   </out>
</xsl:template>
</xsl:stylesheet>
XSLT
  $xsltproc->register_function(
    ("http://x/x", 'test') => sub { $_[0][0]->findnodes('//b[parent::a]') }
   );
  my $stylesheet = $xsltproc->parse_stylesheet($xslt);
  my $result = $stylesheet->transform($parser->parse_string( <<'XML' ));
<a><b><b/></b><b><c/></b></a>
XML
  ok ($result->serialize,qq(<?xml version="1.0"?>\n<out><b><b/></b><b><c/></b></out>\n));
}

{
  my $callbackNS = "http://x/x";

  my $p = XML::LibXML->new;
  my $xsltproc = XML::LibXSLT->new;
  $xsltproc->register_function(
    $callbackNS,
    "some_function",
    sub {
      my($format) = @_;
      return $format;
    }
   );
  $xsltproc->register_function(
    $callbackNS,
    "some_function2",
    sub {
      my($format) = @_;
      return $format->[0];
    }
   );

  my $xsltdoc = $p->parse_string(<<'EOF');
<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0"
     xmlns:xsl="http://www.w3.org/1999/XSL/Transform"  
     xmlns:x="http://x/x"
>

<xsl:template match="root">
  <root>
    <xsl:value-of select="x:some_function(@format)" />
    <xsl:text>,</xsl:text>
    <xsl:value-of select="x:some_function(.)" />
    <xsl:text>,</xsl:text>
    <xsl:value-of select="x:some_function(processing-instruction())" />
    <xsl:text>,</xsl:text>
    <xsl:value-of select="x:some_function(text())" />
    <xsl:text>;</xsl:text>

    <xsl:value-of select="x:some_function2(@format)" />
    <xsl:text>,</xsl:text>
    <xsl:value-of select="x:some_function2(.)" />
    <xsl:text>,</xsl:text>
    <xsl:value-of select="x:some_function2(processing-instruction())" />
    <xsl:text>,</xsl:text>
    <xsl:value-of select="x:some_function2(text())" />
    <xsl:text>;</xsl:text>
    <xsl:for-each select="x:some_function(node())">
      <xsl:value-of select="." />
    </xsl:for-each>
  </root>
</xsl:template>

</xsl:stylesheet>
EOF

  my $doc = $p->parse_string(<<EOF);
<root format="foo">bar<?baz bak?><y>zzz</y></root>
EOF

  my $stylesheet = $xsltproc->parse_stylesheet($xsltdoc);
  my $result = $stylesheet->transform($doc);
  my $val = $result->findvalue("/root");
  ok($val);
  ok($val eq "foo,barzzz,bak,bar;foo,barzzz,bak,bar;barbakzzz")
    or print $stylesheet->output_as_bytes($result);

}
