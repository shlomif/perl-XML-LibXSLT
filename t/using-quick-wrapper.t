
use strict;
use warnings;

use Test::More tests => 9;

use XML::LibXSLT::Quick ();

{
    my $stylesheet = XML::LibXSLT::Quick->new( location => 'example/1.xsl' );
    my $parser     = XML::LibXML->new();

    # TEST
    ok( $parser, 'parser was initialized' );
    my $source = $parser->parse_file('example/1.xml');

    # TEST
    ok( $source, '$source' );
    my $results = $stylesheet->transform($source);
    my $out1    = $stylesheet->output_as_chars($results);

    # TEST
    ok( $out1, 'output' );
}

my $out_exp;
{
    my $xslt_parser = XML::LibXSLT->new();
    my $stylesheet  = XML::LibXSLT::Quick->new(
        xslt_parser => $xslt_parser,
        location    => 'example/1.xsl'
    );
    my $parser = XML::LibXML->new();

    # TEST
    ok( $parser, 'parser was initialized' );
    my $source = $parser->parse_file('example/1.xml');

    # TEST
    ok( $source, '$source' );
    my $results = $stylesheet->transform($source);
    my $out1    = $stylesheet->output_as_chars($results);

    $out_exp = $out1;

    # TEST
    ok( $out1, 'output' );
}

{
    my $stylesheet = XML::LibXSLT::Quick->new( location => 'example/1.xsl' );
    my $parser     = XML::LibXML->new();

    # TEST
    ok( $parser, 'parser was initialized' );
    my $source = $parser->parse_file('example/1.xml');

    # TEST
    ok( $source, '$source' );
    my $out2 = $stylesheet->transform_into_chars($source);

    # TEST
    is( $out2, $out_exp, 'transform_into_chars' );
}
