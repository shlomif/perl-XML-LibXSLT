use Test;
BEGIN { plan tests => 9 }
use XML::LibXSLT;
use XML::LibXML;

my $parser = XML::LibXML->new();
ok($parser);

my $doc = $parser->parse_string(<<'EOT');
<xml>random contents</xml>
EOT

ok($doc);

my $xslt = XML::LibXSLT->new();
ok($xslt);

$xslt->match_callback(\&match_cb);
$xslt->open_callback(\&open_cb);
$xslt->close_callback(\&close_cb);
$xslt->read_callback(\&read_cb);

my $stylesheet = $xslt->parse_stylesheet($parser->parse_string(<<'EOT'));
<xsl:stylesheet version="1.0"
      xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
      xmlns:fo="http://www.w3.org/1999/XSL/Format">

<xsl:template match="/">
<html>
<head><title>Know Your Dromedaries</title></head>
<body>
  <h1><xsl:apply-templates/></h1>
  <p>foo: <xsl:copy-of select="document('foo.xml')" /></p>
</body>
</html>
</xsl:template>

</xsl:stylesheet>
EOT

ok($stylesheet);

# warn "transform!\n";
my $results = $stylesheet->transform($doc);

ok($results);

my $output = $stylesheet->output_string($results);

# warn "output: $output\n";
ok($output);

sub match_cb {
    my $uri = shift;
    if ($uri eq "foo.xml") {
        ok(1);
        return 1;
    }
    return 0;
}

sub open_cb {
    my $uri = shift;
    # warn("open $uri\n");
    ok($uri, "foo.xml");
    return "<foo>Text here</foo>";
}

sub close_cb {
    # warn("close\n");
    ok(1);
}

sub read_cb {
#    warn("read\n");
    return substr($_[0], 0, $_[1], "");
}
