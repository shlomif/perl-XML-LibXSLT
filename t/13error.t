use Test;
BEGIN { plan tests => 12 };

use warnings;
use strict;
$|=1;

use XML::LibXSLT;
ok(1);

my $bad_xsl1 = 'example/bad1.xsl';
my $bad_xsl2 = 'example/bad2.xsl';
my $bad_xsl3 = 'example/bad3.xsl';
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
