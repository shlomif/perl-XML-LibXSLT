use Test;
BEGIN { plan tests => 11 }
use XML::LibXSLT;
use XML::LibXML;

# this test is here because Mark Cox found a segfault
# that occurs when parse_stylesheet is immediately followed
# by a transform()

my $parser = XML::LibXML->new();
my $xslt = XML::LibXSLT->new();
ok($parser); ok($xslt);
my $source = $parser->parse_file('example/1.xml');
ok($source);

my ($out1, $out2);

{
my $style_doc = $parser->parse_file('example/1.xsl');
my $stylesheet = $xslt->parse_stylesheet($style_doc);
my $results = $stylesheet->transform($source);
$out1 = $stylesheet->output_string($results);
ok($out1);
}

{
$source = $parser->parse_file('example/2.xml');
ok($source);
$style_doc = $parser->parse_file('example/2.xsl');
$stylesheet = $xslt->parse_stylesheet($style_doc);
$results = $stylesheet->transform($source);
ok($stylesheet->media_type);
$out2 = $stylesheet->output_string($results);
ok($out2);
}

{
  my $style_doc = $parser->parse_file('example/1.xsl');
  my $stylesheet = $xslt->parse_stylesheet($style_doc);
  my $results = $stylesheet->transform_file('example/1.xml');
  my $out = $stylesheet->output_string($results);
  ok( $out );
  ok( $out1 eq $out );
}

{
  $style_doc = $parser->parse_file('example/2.xsl');
  $stylesheet = $xslt->parse_stylesheet($style_doc);
  $results = $stylesheet->transform_file('example/2.xml');
  my $out = $stylesheet->output_string($results);
  ok( $out );
  ok( $out2 eq $out );
}
