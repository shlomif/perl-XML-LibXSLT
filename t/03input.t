use Test;
BEGIN { plan tests => 12 }
use XML::LibXSLT;
use XML::LibXML;

my $parser = XML::LibXML->new();
print "# parser\n";
ok($parser);

my $doc = $parser->parse_string(<<'EOT');
<xml>random contents</xml>
EOT

print "# doc\n";
ok($doc);

my $xslt = XML::LibXSLT->new();
print "# xslt\n";
ok($xslt);

print "# setting callbacks\n";
local $XML::LibXSLT::match_cb = \&match_cb;
local $XML::LibXSLT::open_cb = \&open_cb;
local $XML::LibXSLT::close_cb = \&close_cb;
local $XML::LibXSLT::read_cb = \&read_cb;

my $stylesheet = $xslt->parse_stylesheet($parser->parse_string(<<'EOT'));
<xsl:stylesheet version="1.0"
      xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
      xmlns:fo="http://www.w3.org/1999/XSL/Format">

<xsl:template match="/">
<html>
<head><title>Know Your Dromedaries</title></head>
<body>
  <h1><xsl:apply-templates/></h1>
  <p>foo: <xsl:apply-templates select="document('foo.xml')/*" /></p>
</body>
</html>
</xsl:template>

</xsl:stylesheet>
EOT

print "# stylesheet\n";
ok($stylesheet);

# warn "transform!\n";
my $results = $stylesheet->transform($doc);

print "# results\n";
ok($results);

my $output = $stylesheet->output_string($results);

# warn "output: $output\n";
print "# output\n";
ok($output);

$XML::LibXSLT::open_cb = \&dying_open_cb;

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
    print "# match_cb: $uri\n";
    if ($uri eq "foo.xml") {
        ok(1);
        return 1;
    }
    return 0;
}

sub open_cb {
    my $uri = shift;
    print "# open_cb: $uri\n";
    ok($uri, "foo.xml");
    return "<foo>Text here</foo>";
}

sub dying_open_cb {
    my $uri = shift;
    print "# dying_open_cb: $uri\n";
    ok($uri, "foo.xml");
    die "Test a die from open_cb";
}

sub close_cb {
    print "# close_cb\n";
    # warn("close\n");
    ok(1);
}

sub read_cb {
    print "# read_cb\n";
#    warn("read\n");
    return substr($_[0], 0, $_[1], "");
}
