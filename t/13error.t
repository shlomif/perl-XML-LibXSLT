use Test;
BEGIN { plan tests => 28 };

use warnings;
use strict;
$|=1;

use XML::LibXSLT;
ok(1);

my $bad_xsl1 = 'example/bad1.xsl';
my $bad_xsl2 = 'example/bad2.xsl';
my $bad_xsl3 = 'example/bad3.xsl';
my $fatal_xsl = 'example/fatal.xsl';
my $nonfatal_xsl = 'example/nonfatal.xsl';
my $good_xsl = 'example/1.xsl';
my $good_xml = 'example/1.xml';
my $bad_xml  = 'example/bad2.xsl';

my $xslt = XML::LibXSLT->new;
ok($xslt);

{
  my $stylesheet = XML::LibXML->new->parse_file($bad_xsl1);
  undef $@;
  eval { $xslt->parse_stylesheet($stylesheet) };
  ok( $@ );
}

{
  undef $@;
  eval { XML::LibXML->new->parse_file($bad_xsl2) };
  ok( $@ );
}

{
  my $stylesheet = XML::LibXML->new->parse_file($good_xsl);
  ok( $stylesheet );
  my $parsed = $xslt->parse_stylesheet( $stylesheet );
  ok( $parsed );
  undef $@;
  eval { $parsed->transform_file( $bad_xml ); };
  ok( $@ );
}

{
  my $stylesheet = XML::LibXML->new->parse_file($nonfatal_xsl);
  ok( $stylesheet );
  my $parsed = $xslt->parse_stylesheet( $stylesheet );
  ok( $parsed );
  undef $@;
  my $warn;
  local $SIG{__WARN__} = sub { $warn = shift; };
  eval { $parsed->transform_file( $good_xml ); };
  ok( !$@ );
  ok( $warn , "Non-fatal message.\n" );
}

{
  my $parser = XML::LibXML->new;
  my $stylesheet = $parser->parse_file($bad_xsl3);
  ok( $stylesheet );
  my $parsed = $xslt->parse_stylesheet( $stylesheet );
  ok( $parsed );
  undef $@;
  eval { $parsed->transform_file( $good_xml ); };
  ok( $@ );
  my $dom = $parser->parse_file( $good_xml );
  ok( $dom );
  undef $@;
  eval { $parsed->transform( $dom ); };
  ok( $@ );
}

{
  my $parser = XML::LibXML->new;
  my $stylesheet = $parser->parse_file($fatal_xsl);
  ok( $stylesheet );
  my $parsed = $xslt->parse_stylesheet( $stylesheet );
  ok( $parsed );
  undef $@;
  eval { $parsed->transform_file( $good_xml ); };
  ok( $@ );
  my $dom = $parser->parse_file( $good_xml );
  ok( $dom );
  undef $@;
  eval { $parsed->transform( $dom ); };
  ok( $@ );
}

{
my $parser = XML::LibXML->new();
ok( $parser );

my $doc = $parser->parse_string(<<XML);
<doc/>
XML
ok( $doc );

my $xslt = XML::LibXSLT->new();
my $style_doc = $parser->parse_string(<<XSLT);
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:template match="/">
    <xsl:value-of select="\$foo"/>
  </xsl:template>
</xsl:stylesheet>
XSLT
ok( $style_doc );

my $stylesheet = $xslt->parse_stylesheet($style_doc);
ok( $stylesheet );

my $results;
eval { $results = $stylesheet->transform($doc); };
ok( $@ );

ok( $@ =~ /unregistered variable foo|variable 'foo' has not been declared/i );
ok( $@ =~ /element value-of/ );

}