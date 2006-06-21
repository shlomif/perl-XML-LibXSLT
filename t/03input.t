use Test;
BEGIN { plan tests => 25 }
use XML::LibXSLT;
use XML::LibXML 1.59;

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

my $stylsheetstring = <<'EOT';
<xsl:stylesheet version="1.0"
      xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
      xmlns="http://www.w3.org/1999/xhtml">

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

my $icb = XML::LibXML::InputCallback->new();
ok($icb);

print "# registering callbacks\n";
$icb->register_callbacks( [ \&match_cb, \&open_cb,
                            \&read_cb, \&close_cb ] );

$xslt->input_callbacks($icb);
                
my $stylesheet = $xslt->parse_stylesheet($parser->parse_string($stylsheetstring));
print "# stylesheet\n";
ok($stylesheet);

#$stylesheet->input_callbacks($icb);

# warn "transforming\n";
my $results = $stylesheet->transform($doc);
print "# results\n";
ok($results);

my $output = $stylesheet->output_string($results);
# warn "output: $output\n";
print "# output\n";
ok($output);

# test a dying close callback
# callbacks can only be registered as a callback group
$stylesheet->match_callback( \&match_cb );
$stylesheet->open_callback( \&dying_open_cb );
$stylesheet->read_callback( \&read_cb );
$stylesheet->close_callback( \&close_cb );

# check if transform throws an exception
print "# dying callback test\n";
eval {
    $stylesheet->transform($doc);
};
if ($@) {
    ok(1, 1, "Threw: $@");
}
else {
    ok(0, 1, "No error");
}

#
# test the old global|local-variables-using callback interface
#

$xslt = undef;
$stylesheet = undef;
$xslt = XML::LibXSLT->new();
$stylesheet = $xslt->parse_stylesheet($parser->parse_string($stylsheetstring));

print "# setting callbacks\n";
local $XML::LibXML::match_cb = \&match_cb;
local $XML::LibXML::open_cb = \&open_cb;
local $XML::LibXML::close_cb = \&close_cb;
local $XML::LibXML::read_cb = \&read_cb;

# warn "transform!\n";
$results = $stylesheet->transform($doc);

print "# results\n";
ok($results);

$output = $stylesheet->output_string($results);

# warn "output: $output\n";
print "# output\n";
ok($output);

$XML::LibXML::open_cb = \&dying_open_cb;

# check if the transform throws an exception
eval {
    $stylesheet->transform($doc);
};
if ($@) {
    ok(1, 1, "Threw: $@");
}
else {
    ok(0, 1, "No error");
}

#
# test callbacks for parse_stylesheet()
#

$xslt = undef;
$stylesheet = undef;
$icb = undef;

$xslt = XML::LibXSLT->new();
$icb = XML::LibXML::InputCallback->new();

print "# registering callbacks\n";
$icb->register_callbacks( [ \&match_cb, \&stylesheet_open_cb,
                            \&read_cb, \&close_cb ] );

$xslt->input_callbacks($icb);

$stylsheetstring = <<'EOT';
<xsl:stylesheet version="1.0"
      xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
      xmlns="http://www.w3.org/1999/xhtml">

<xsl:import href="foo.xml"/>

<xsl:template match="/">
<html>
<head><title>Know Your Dromedaries</title></head>
<body>
  <h1><xsl:apply-templates/></h1>
  <p>Dahut!</p>
</body>
</html>
</xsl:template>

</xsl:stylesheet>
EOT

$stylesheet = $xslt->parse_stylesheet($parser->parse_string($stylsheetstring));
print "# stylesheet\n";
ok($stylesheet);

#
# input callback functions
#

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
    my $str ="<foo>Text here</foo>";
    return \$str;
}

sub dying_open_cb {
    my $uri = shift;
    print "# dying_open_cb: $uri\n";
    ok($uri, "foo.xml");
    die "Test a die from open_cb";
}

sub stylesheet_open_cb {
    my $uri = shift;
    print "# open_cb: $uri\n";
    ok($uri, "foo.xml");
    my $str = '<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"/>';
    return \$str;
}

sub close_cb {
    print "# close_cb\n";
    # warn("close\n");
    ok(1);
}

sub read_cb {
    print "# read_cb\n";
#    warn("read\n");
    return substr(${$_[0]}, 0, $_[1], "");
}
