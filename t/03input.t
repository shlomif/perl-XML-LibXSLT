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

# warn("setting callbacks\n");
local $XML::LibXML::match_cb = \&match_cb;
local $XML::LibXML::open_cb = \&open_cb;
local $XML::LibXML::close_cb = \&close_cb;
local $XML::LibXML::read_cb = \&read_cb;

$xslt->callbacks(\&match_cb, \&open_cb, \&read_cb, \&close_cb);

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

$xslt->callbacks(\&match_cb, \&broken_open_cb, \&read_cb, \&close_cb);

# check transform throws exception
eval {
    $stylesheet->transform($doc);
};
if ($@) {
    ok(1, 1, "Threw: $@");
}
else {
    ok(0, 1, "No error");
}

$xslt->callbacks(\&match_cb, \&dying_open_cb, \&read_cb, \&close_cb);

# check transform throws exception
eval {
    $stylesheet->transform($doc);
};
if ($@) {
    ok(1, 1, "Threw: $@");
}
else {
    ok(0, 1, "No error");
}

sub match_cb {
    my $uri = shift;
#    warn("match: $uri\n");
    if ($uri eq "foo.xml") {
        ok(1);
        return 1;
    }
    return 0;
}

sub open_cb {
    my $uri = shift;
#    warn("open $uri\n");
    ok($uri, "foo.xml");
    return "<foo>Text here</foo>";
}

sub broken_open_cb {
    my $uri = shift;
    ok($uri, "foo.xml");
    return ""; # sending blank breaks things
}

sub dying_open_cb {
    my $uri = shift;
    ok($uri, "foo.xml");
    die "Test a die from open_cb";
}

sub close_cb {
    # warn("close\n");
    ok(1);
}

sub read_cb {
#    warn("read\n");
    return substr($_[0], 0, $_[1], "");
}
